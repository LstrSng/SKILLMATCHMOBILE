import "dotenv/config";
import cors from "cors";
import express from "express";
import mongoose from "mongoose";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import crypto from "crypto";
import MobileUser from "./models/mobile_user.js";
import Job from "./models/job.js";
import Application from "./models/application.js";
import Otp from "./models/otp.js";
import TrustedDevice from "./models/trusted_device.js";
import EmployerAccount from "./models/employer_account.js";
import Assessment from "./models/assessment.js";
import { normalizeJobDoc } from "./jobNormalize.js";
import { generateNumericOtp, hashOtp } from "./utils/otp.js";
import { generateDeviceToken, hashDeviceToken } from "./utils/device_token.js";
import { sendMail } from "./utils/mailer.js";
import { readStoredSkills, toStoredSkills } from "./utils/skill_groups.js";

const DEFAULT_PORT = 5003;
const PORT = Number(process.env.PORT) || DEFAULT_PORT;
// Some setups use `MONGODB_URI`, others use `MONGO_URI`.
const MONGODB_URI = process.env.MONGODB_URI || process.env.MONGO_URI;
const JWT_SECRET = process.env.JWT_SECRET;

if (!MONGODB_URI) {
  console.error("Missing MONGODB_URI (or MONGO_URI) in .env");
  process.exit(1);
}
if (!JWT_SECRET) {
  console.error("Missing JWT_SECRET in .env");
  process.exit(1);
}

// Mobile app auth uses the dedicated mobile user model.
const User = MobileUser;

const app = express();
app.use(cors());
app.use(express.json({ limit: "60mb" }));
app.use(express.urlencoded({ extended: true, limit: "60mb" }));

function requireDb(req, res, next) {
  // 1 = connected (https://mongoosejs.com/docs/api/connection.html#Connection.prototype.readyState)
  if (mongoose.connection.readyState === 1) return next();
  return res.status(503).json({
    message:
      "Database is not connected yet. Check your MongoDB connection string and network/DNS, then restart the API.",
  });
}

function generateToken(id) {
  return jwt.sign({ id }, JWT_SECRET, { expiresIn: "30d" });
}

function generatePasswordResetToken(email) {
  return jwt.sign({ email, typ: "password_reset" }, JWT_SECRET, {
    expiresIn: "10m",
  });
}

const OTP_TTL_MS = 10 * 60 * 1000;
const OTP_MAX_ATTEMPTS = 5;
const OTP_RESEND_WINDOW_MS = 15 * 60 * 1000;
const OTP_MAX_SENDS_PER_WINDOW = 3;
const DEVICE_TRUST_TTL_MS = 30 * 24 * 60 * 60 * 1000;

function getBearerToken(req) {
  const h = req.headers?.authorization;
  if (!h || typeof h !== "string") return null;
  const parts = h.split(" ");
  if (parts.length === 2 && parts[0].toLowerCase() === "bearer") return parts[1];
  return null;
}

async function requireAuth(req, res, next) {
  try {
    const token = getBearerToken(req);
    if (!token) return res.status(401).json({ message: "Missing auth token." });
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = await User.findById(decoded?.id).lean();
    if (!user) return res.status(401).json({ message: "Invalid auth token." });
    req.user = user;
    next();
  } catch (_e) {
    return res.status(401).json({ message: "Invalid auth token." });
  }
}

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

function isValidEmail(email) {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(String(email || "").trim());
}

async function enforceSendRateLimit({ email, purpose }) {
  const since = new Date(Date.now() - OTP_RESEND_WINDOW_MS);
  const count = await Otp.countDocuments({
    email,
    purpose,
    createdAt: { $gte: since },
  });
  return count < OTP_MAX_SENDS_PER_WINDOW;
}

async function createAndSendOtp({ email, purpose }) {
  const canSend = await enforceSendRateLimit({ email, purpose });
  if (!canSend) {
    return {
      ok: false,
      status: 429,
      message: "Too many OTP requests. Please try again later.",
    };
  }

  const otp = generateNumericOtp(6);
  const challengeId = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + OTP_TTL_MS);

  await Otp.create({
    email,
    purpose,
    challengeId,
    codeHash: hashOtp({ email, purpose, otp }),
    expiresAt,
  });

  try {
    await sendMail({
      to: email,
      subject: "Your SkillMatch OTP code",
      text: `Your OTP code is: ${otp}\n\nThis code expires in 10 minutes.\n\nIf you did not request this, you can ignore this email.`,
    });
  } catch (err) {
    console.error("[otp] send failed", {
      email,
      purpose,
      challengeId,
      message: err?.message,
      code: err?.code,
      response: err?.response,
      responseCode: err?.responseCode,
    });
    return {
      ok: false,
      status: 500,
      message: "We couldn't send the verification code. Please try again in a moment.",
    };
  }

  return { ok: true, challengeId };
}

async function verifyOtp({ email, purpose, otp, challengeId }) {
  const doc = await Otp.findOne({ email, purpose, challengeId }).sort({
    createdAt: -1,
  });

  if (!doc) return { ok: false, status: 400, message: "Invalid OTP challenge." };
  if (doc.consumedAt) return { ok: false, status: 400, message: "OTP already used." };
  if (doc.expiresAt <= new Date()) {
    return { ok: false, status: 400, message: "OTP expired." };
  }
  if (doc.attemptCount >= OTP_MAX_ATTEMPTS) {
    return {
      ok: false,
      status: 429,
      message: "Too many attempts. Request a new OTP.",
    };
  }

  doc.attemptCount += 1;
  const isMatch = doc.codeHash === hashOtp({ email, purpose, otp });
  if (isMatch) {
    doc.consumedAt = new Date();
  }
  await doc.save();

  if (!isMatch) {
    return { ok: false, status: 400, message: "Invalid OTP." };
  }

  return { ok: true };
}

function userPublic(u) {
  if (!u) return null;
  const storedSkills = readStoredSkills(u);
  const education = Array.isArray(u.education)
    ? u.education
        .map((it) => ({
          degree: String(it?.degree ?? "").trim(),
          school: String(it?.school ?? "").trim(),
          years: String(it?.years ?? "").trim(),
        }))
        .filter((it) => it.degree || it.school || it.years)
    : [];
  const experience = Array.isArray(u.experience)
    ? u.experience
        .map((it) => ({
          year: String(it?.year ?? "").trim(),
          title: String(it?.title ?? "").trim(),
          company: String(it?.company ?? "").trim(),
          description: String(it?.description ?? "").trim(),
        }))
        .filter((it) => it.year || it.title || it.company || it.description)
    : [];
  return {
    _id: u._id,
    email: u.email,
    firstName: u.firstName,
    lastName: u.lastName,
    headline: u.headline || "",
    location: u.location || "",
    phone: u.phone || "",
    portfolioUrl: u.portfolioUrl || "",
    bio: u.bio || "",
    avatarUrl: u.avatarUrl || "",
    // The app works with a flat list plus a { name: level } map; the
    // database stores them grouped (see toStoredSkills).
    skills: storedSkills.names,
    skillLevels: storedSkills.levels,
    education,
    experience,
    profile: u.profile && typeof u.profile === "object" ? u.profile : {},
  };
}

app.get("/api/health", (_req, res) => {
  res.json({ ok: true, db: mongoose.connection.readyState === 1 });
});

app.get("/test", (_req, res) => {
  res.send("test");
});

const JOBS_QUERY_LIMIT = Math.min(
  Math.max(Number(process.env.JOBS_QUERY_LIMIT) || 100, 1),
  500
);

function stripLevelSuffix(str) {
  return String(str || "")
    .trim()
    .replace(/\s*\(?\s*(?:level\s*\d+(?:\s*-\s*\d+)?|lvl\s*\d+|beginner|intermediate|advanced|basic|expert)\s*\)?\s*$/i, "")
    .trim();
}

// Jobs stored in MongoDB (collection: JOBS_COLLECTION, default `jobs`)
app.get("/api/jobs", requireDb, async (req, res) => {
  try {
    const raw = await Job.find({})
      .sort({ _id: -1 })
      .limit(JOBS_QUERY_LIMIT)
      .lean();

    // Job postings usually don't repeat the company name on the job itself —
    // it lives on the employer account that posted it (`postedBy`). Batch
    // resolve those so `normalizeJobDoc` can fall back to it.
    const posterIds = [
      ...new Set(
        raw
          .map((d) => d.postedBy)
          .filter((v) => v && mongoose.Types.ObjectId.isValid(v))
          .map((v) => String(v))
      ),
    ];
    let postersById = new Map();
    if (posterIds.length) {
      try {
        const posters = await EmployerAccount.find(
          { _id: { $in: posterIds } },
          { companyName: 1, logoUrl: 1 }
        ).lean();
        postersById = new Map(posters.map((p) => [String(p._id), p]));
      } catch (e) {
        console.error("Poster lookup error:", e);
      }
    }

    // Try to resolve an authenticated applicant (optional). If a valid bearer
    // token is present, compute per-job matched/unmatched skills and score.
    let applicant = null;
    try {
      const token = getBearerToken(req);
      if (token) {
        const decoded = jwt.verify(token, JWT_SECRET);
        if (decoded?.id) applicant = await User.findById(decoded.id).lean();
      }
    } catch (e) {
      // Ignore auth errors; we will return unauthenticated jobs if token invalid.
      applicant = null;
    }

    const applicantSkillsSet = applicant
      ? new Set(
          readStoredSkills(applicant)
            .names.map((s) => String(s).trim().toLowerCase())
            .filter(Boolean)
            .flatMap((s) => [s, stripLevelSuffix(s).toLowerCase()])
        )
      : null;

    const jobs = raw.map((doc) => {
      const poster = doc.postedBy ? postersById.get(String(doc.postedBy)) : null;
      const job = normalizeJobDoc(doc, poster);

      if (applicantSkillsSet) {
        const allSkills = [
          ...(Array.isArray(job.matchedSkills) ? job.matchedSkills : []),
          ...(Array.isArray(job.unmatchedSkills) ? job.unmatchedSkills : []),
        ];
        const seen = new Set();
        const jobSkills = [];
        for (const s of allSkills) {
          const norm = String(s ?? "").trim();
          if (!norm) continue;
          const key = norm.toLowerCase();
          if (!seen.has(key)) {
            seen.add(key);
            jobSkills.push(norm);
          }
        }

        const matchedSkills = [];
        const missingSkills = [];
        for (const s of jobSkills) {
          const rawSkill = String(s ?? "").trim();
          if (!rawSkill) continue;
          if (
            applicantSkillsSet.has(rawSkill.toLowerCase()) ||
            applicantSkillsSet.has(stripLevelSuffix(rawSkill).toLowerCase())
          ) {
            matchedSkills.push(rawSkill);
          } else {
            missingSkills.push(rawSkill);
          }
        }

        const total = matchedSkills.length + missingSkills.length;
        const matchScore = total > 0 ? Math.round((matchedSkills.length / total) * 100) : (Number(job.matchPercentage) || 0);

        job.matchedSkills = matchedSkills;
        job.unmatchedSkills = missingSkills;
        job.matchPercentage = matchScore;
      }

      return job;
    });

    return res.json({ jobs });
  } catch (err) {
    console.error("Jobs list error:", err);
    return res.status(500).json({ message: "Could not load jobs." });
  }
});

// Company details for the employer that posted a given job
app.get("/api/jobs/:id/company", requireDb, async (req, res) => {
  try {
    const { id } = req.params;
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(400).json({ message: "Invalid job id." });
    }

    const jobDoc = await Job.findById(id).lean();
    if (!jobDoc) return res.status(404).json({ message: "Job not found." });

    let poster = null;
    if (jobDoc.postedBy && mongoose.Types.ObjectId.isValid(jobDoc.postedBy)) {
      poster = await EmployerAccount.findById(jobDoc.postedBy).lean();
    }

    const name = String(
      poster?.companyName ||
      poster?.company ||
      poster?.name ||
      poster?.organization ||
      jobDoc.company ||
      jobDoc.companyName ||
      ""
    ).trim();

    if (!poster && !name) {
      return res.status(404).json({ message: "No company info for this job." });
    }

    const bio = String(
      poster?.companyBio ||
      poster?.bio ||
      poster?.about ||
      poster?.description ||
      poster?.overview ||
      jobDoc.companyBio ||
      jobDoc.companyDescription ||
      ""
    ).trim();

    const website = String(
      poster?.website ||
      poster?.companyWebsite ||
      jobDoc.companyWebsite ||
      jobDoc.website ||
      ""
    ).trim();

    const location = String(
      poster?.location ||
      poster?.companyLocation ||
      poster?.address ||
      jobDoc.location ||
      jobDoc.companyLocation ||
      ""
    ).trim();

    const contactNumber = String(
      poster?.contactNumber ||
      poster?.phone ||
      poster?.phoneNumber ||
      poster?.contact ||
      jobDoc.contactNumber ||
      ""
    ).trim();

    const email = String(
      poster?.email ||
      poster?.companyEmail ||
      poster?.contactEmail ||
      jobDoc.email ||
      jobDoc.contactEmail ||
      ""
    ).trim();

    const logoUrl = String(
      poster?.logoUrl ||
      poster?.logo ||
      poster?.companyLogo ||
      poster?.avatarUrl ||
      poster?.avatar ||
      poster?.profilePicture ||
      jobDoc.logoUrl ||
      jobDoc.companyLogo ||
      jobDoc.logo ||
      ""
    ).trim();

    const bannerUrl = String(
      poster?.bannerUrl ||
      poster?.banner ||
      poster?.coverUrl ||
      poster?.coverImage ||
      poster?.headerImage ||
      poster?.companyBanner ||
      jobDoc.bannerUrl ||
      jobDoc.coverUrl ||
      jobDoc.banner ||
      ""
    ).trim();

    const industry = String(
      poster?.industry ||
      poster?.category ||
      poster?.sector ||
      jobDoc.industry ||
      ""
    ).trim();

    const companySize = String(
      poster?.companySize ||
      poster?.size ||
      poster?.employeeCount ||
      poster?.employees ||
      jobDoc.companySize ||
      ""
    ).trim();

    const contactName = poster
      ? [poster.firstName, poster.lastName]
          .map((v) => String(v ?? "").trim())
          .filter(Boolean)
          .join(" ")
      : String(jobDoc.contactPerson || jobDoc.contactName || "").trim();

    const memberSince = poster?.createdAt
      ? new Date(poster.createdAt).toISOString()
      : (jobDoc.createdAt ? new Date(jobDoc.createdAt).toISOString() : "");

    const rawPhotos =
      poster?.photos ||
      poster?.images ||
      poster?.companyImages ||
      poster?.gallery ||
      jobDoc.photos ||
      jobDoc.images ||
      [];
    const photos = Array.isArray(rawPhotos)
      ? rawPhotos.map((p) => String(p ?? "").trim()).filter(Boolean)
      : [];

    return res.json({
      company: {
        name: name || "Company",
        bio,
        website,
        location,
        contactNumber,
        logoUrl,
        bannerUrl,
        email,
        contactName,
        industry,
        companySize,
        memberSince,
        photos,
        jobTitle: String(jobDoc.title || jobDoc.jobTitle || "").trim(),
      },
    });
  } catch (err) {
    console.error("Company details error:", err);
    return res.status(500).json({ message: "Could not load company details." });
  }
});

// ==========================================
// Assessment APIs (MongoDB backed)
// ==========================================

// List all published assessments from MongoDB
app.get("/api/assessments", requireDb, async (req, res) => {
  try {
    const { track, search, roleId } = req.query ?? {};
    const filter = { isPublished: { $ne: false } };

    if (track && String(track).trim() && String(track).trim().toLowerCase() !== "all") {
      filter.track = String(track).trim();
    }
    if (roleId && String(roleId).trim()) {
      filter.roleId = String(roleId).trim();
    }
    if (search && String(search).trim()) {
      const q = String(search).trim();
      filter.$or = [
        { title: { $regex: q, $options: "i" } },
        { roleTitle: { $regex: q, $options: "i" } },
        { roleId: { $regex: q, $options: "i" } },
        { track: { $regex: q, $options: "i" } },
      ];
    }

    const docs = await Assessment.find(filter)
      .sort({ track: 1, roleTitle: 1 })
      .lean();

    const assessments = docs.map((d) => ({
      _id: String(d._id),
      roleId: d.roleId || "",
      roleTitle: d.roleTitle || d.title || "",
      title: d.title || "",
      track: d.track || "General",
      description: d.description || "",
      passingScorePercentage: Number(d.passingScorePercentage) || 70,
      timeLimitMinutes: Number(d.timeLimitMinutes) || 25,
      questionsCount: Array.isArray(d.questions) ? d.questions.length : 0,
      questions: Array.isArray(d.questions)
        ? d.questions.map((q) => ({
            questionId: q.questionId || String(q._id || ""),
            prompt: q.prompt || "",
            type: q.type || "multiple_choice",
            options: Array.isArray(q.options) ? q.options : [],
            correctAnswer: q.correctAnswer || "",
            explanation: q.explanation || "",
            competency: q.competency || "",
            skillType: q.skillType || "Functional Competency",
            difficulty: q.difficulty || "Mid-Level",
            points: Number(q.points) || 5,
            timeLimitSeconds: Number(q.timeLimitSeconds) || 120,
          }))
        : [],
    }));

    return res.json({ assessments, total: assessments.length });
  } catch (err) {
    console.error("Fetch assessments error:", err);
    return res.status(500).json({ message: "Could not load assessments." });
  }
});

// Get a single assessment with full questions by ID or roleId
app.get("/api/assessments/:id", requireDb, async (req, res) => {
  try {
    const { id } = req.params;
    let doc = null;

    if (mongoose.Types.ObjectId.isValid(id)) {
      doc = await Assessment.findById(id).lean();
    }
    if (!doc) {
      doc = await Assessment.findOne({ roleId: id }).lean();
    }
    if (!doc) {
      return res.status(404).json({ message: "Assessment not found." });
    }

    const assessment = {
      _id: String(doc._id),
      roleId: doc.roleId || "",
      roleTitle: doc.roleTitle || doc.title || "",
      title: doc.title || "",
      track: doc.track || "General",
      description: doc.description || "",
      passingScorePercentage: Number(doc.passingScorePercentage) || 70,
      timeLimitMinutes: Number(doc.timeLimitMinutes) || 25,
      questionsCount: Array.isArray(doc.questions) ? doc.questions.length : 0,
      questions: Array.isArray(doc.questions)
        ? doc.questions.map((q) => ({
            questionId: q.questionId || String(q._id || ""),
            prompt: q.prompt || "",
            type: q.type || "multiple_choice",
            options: Array.isArray(q.options) ? q.options : [],
            correctAnswer: q.correctAnswer || "",
            explanation: q.explanation || "",
            competency: q.competency || "",
            skillType: q.skillType || "Functional Competency",
            difficulty: q.difficulty || "Mid-Level",
            points: Number(q.points) || 5,
            timeLimitSeconds: Number(q.timeLimitSeconds) || 120,
          }))
        : [],
    };

    return res.json({ assessment });
  } catch (err) {
    console.error("Fetch single assessment error:", err);
    return res.status(500).json({ message: "Could not load assessment details." });
  }
});

// Submit assessment results and persist to MongoDB user profile
app.post("/api/assessments/:id/submit", requireDb, async (req, res) => {
  try {
    const { id } = req.params;
    let doc = null;
    if (mongoose.Types.ObjectId.isValid(id)) {
      doc = await Assessment.findById(id).lean();
    }
    if (!doc) {
      doc = await Assessment.findOne({ roleId: id }).lean();
    }

    const body = req.body ?? {};
    let correctCount = 0;
    let totalCount = Array.isArray(doc?.questions) && doc.questions.length > 0
      ? doc.questions.length
      : Math.max(1, Number(body.totalCount) || 1);

    if (Array.isArray(body.answers) && doc?.questions?.length) {
      // Grade on the server: each question counts once, only answers that
      // match the stored answer key are correct, and the score is out of
      // the questions actually asked (the test is adaptive, so that can be
      // fewer than all of the assessment's questions).
      const graded = new Set();
      let computedCorrect = 0;
      for (const ans of body.answers) {
        if (!ans) continue;
        const qId = String(ans.questionId || "").trim();
        const selAns = String(ans.selectedAnswer ?? "").trim().toLowerCase();
        const q = doc.questions.find(
          (item) =>
            (qId && (item.questionId === qId || String(item._id) === qId)) ||
            (ans.prompt && item.prompt && item.prompt.trim() === ans.prompt.trim())
        );
        if (!q) continue;
        const key = String(q._id ?? q.questionId ?? q.prompt);
        if (graded.has(key)) continue;
        graded.add(key);
        const target = String(q.correctAnswer ?? "").trim().toLowerCase();
        if (selAns && target && selAns === target) computedCorrect += 1;
      }
      totalCount = Math.max(1, graded.size);
      correctCount = computedCorrect;
    } else {
      correctCount = Math.max(0, Math.min(Number(body.correctCount) || 0, totalCount));
      totalCount = Math.max(1, Number(body.totalCount) || totalCount);
    }

    const percentage = Math.max(0, Math.min(100, Math.round((correctCount / totalCount) * 100)));
    const passingThreshold = Number(doc?.passingScorePercentage) || 70;
    const passed = percentage >= passingThreshold;

    let level = "Beginner";
    if (percentage >= 85) level = "Job-ready";
    else if (percentage >= 70) level = "Advanced";
    else if (percentage >= 50) level = "Intermediate";

    const result = {
      assessmentId: doc ? String(doc._id) : id,
      roleId: doc?.roleId || id,
      roleTitle: doc?.roleTitle || doc?.title || "Skill Assessment",
      track: doc?.track || "General",
      level,
      scorePercentage: percentage,
      correctCount,
      totalCount,
      passed,
      passingScorePercentage: passingThreshold,
      takenAt: new Date().toISOString(),
    };

    // If authenticated, update user document
    const token = getBearerToken(req);
    let updatedUser = null;
    if (token) {
      try {
        const decoded = jwt.verify(token, JWT_SECRET);
        if (decoded?.id) {
          const user = await User.findById(decoded.id);
          if (user) {
            const currentProfile = (user.profile && typeof user.profile === "object") ? { ...user.profile } : {};
            const currentAssessments = (currentProfile.skillAssessments && typeof currentProfile.skillAssessments === "object")
              ? { ...currentProfile.skillAssessments }
              : {};

            const categoryKey = doc?.roleId || id;
            currentAssessments[categoryKey] = {
              level,
              ability: Number((percentage / 25).toFixed(2)),
              correctCount,
              totalCount,
              scorePercentage: percentage,
              passed,
              roleTitle: result.roleTitle,
              track: result.track,
              takenAt: result.takenAt,
            };

            const currentRecords = Array.isArray(currentProfile.assessmentRecords)
              ? [...currentProfile.assessmentRecords]
              : [];
            currentRecords.unshift({
              categoryKey,
              roleId: categoryKey,
              roleTitle: result.roleTitle,
              track: result.track,
              level,
              scorePercentage: percentage,
              correctCount,
              totalCount,
              passed,
              takenAt: result.takenAt,
            });
            if (currentRecords.length > 50) {
              currentRecords.length = 50;
            }
            currentProfile.assessmentRecords = currentRecords;

            currentProfile.skillAssessments = currentAssessments;
            user.profile = currentProfile;
            user.markModified("profile");
            await user.save();
            updatedUser = userPublic(user.toObject());
          }
        }
      } catch (authErr) {
        console.warn("Could not save to authenticated user:", authErr.message);
      }
    }

    return res.json({
      ok: true,
      result,
      user: updatedUser,
      message: passed ? "Congratulations! You passed the assessment." : "Assessment completed.",
    });
  } catch (err) {
    console.error("Submit assessment error:", err);
    return res.status(500).json({ message: "Could not submit assessment." });
  }
});

// OTP-backed auth flows
app.post("/api/users/register", requireDb, async (req, res) => {
  return res.status(400).json({
    message:
      "Registration requires OTP verification. Use /api/users/register/otp/request then /api/users/register/otp/verify.",
  });
});

// Returns an error message if the sign-up fields are invalid, else null.
function signupValidationError({ firstName, lastName, email, phone, password }) {
  if (!firstName || !lastName || !email || !phone || !password) {
    return "Missing required fields.";
  }
  const namePattern = /^[\p{L}][\p{L} .'-]{0,49}$/u;
  if (!namePattern.test(firstName) || !namePattern.test(lastName)) {
    return "Names may only contain letters, spaces, periods, hyphens, and apostrophes.";
  }
  if (!isValidEmail(email)) return "Please enter a valid email address.";
  if (!/^09\d{9}$/.test(phone)) {
    return "Contact number must be 11 digits and start with 09.";
  }
  return passwordError(password);
}

// Returns an error message if [password] is too weak, else null. Used by
// sign-up and password reset so both enforce the same rule.
function passwordError(password) {
  if (
    password.length < 8 ||
    !/[A-Z]/.test(password) ||
    !/[a-z]/.test(password) ||
    !/\d/.test(password) ||
    !/[^A-Za-z0-9]/.test(password)
  ) {
    return "Password must be at least 8 characters and include uppercase, lowercase, number, and special character.";
  }
  return null;
}

function readSignupFields(body) {
  return {
    firstName: String(body?.firstName || "").trim(),
    lastName: String(body?.lastName || "").trim(),
    email: normalizeEmail(body?.email),
    phone: String(body?.phone || "").trim(),
    password: String(body?.password || ""),
  };
}

// Creates the account right away (unverified), then emails a code to verify
// it. Skipping the code is fine: the user can still sign in later.
// Called with only { email } to resend the code for an unverified account.
app.post("/api/users/register/otp/request", requireDb, async (req, res) => {
  try {
    const fields = readSignupFields(req.body);
    const { email } = fields;
    if (!email) {
      return res.status(400).json({ message: "email is required." });
    }
    if (!isValidEmail(email)) {
      return res.status(400).json({ message: "Please enter a valid email address." });
    }

    const isResend = !fields.password;
    const existing = await User.findOne({ email }).select("_id emailVerified").lean();

    if (isResend) {
      if (!existing) {
        return res.status(400).json({ message: "No account found for that email." });
      }
      if (existing.emailVerified !== false) {
        return res.status(400).json({ message: "This email is already verified. Please sign in." });
      }
    } else {
      if (existing) {
        return res.status(400).json({
          message: "An account with that email already exists. Please sign in.",
        });
      }
      const error = signupValidationError(fields);
      if (error) return res.status(400).json({ message: error });

      await User.create({
        email,
        password: await bcrypt.hash(fields.password, 10),
        firstName: fields.firstName,
        lastName: fields.lastName,
        phone: fields.phone,
        emailVerified: false,
      });
    }

    const result = await createAndSendOtp({ email, purpose: "signup" });
    if (!result.ok) {
      const message = isResend
        ? result.message
        : "Your account was created, but we couldn't send the verification code. You can sign in now.";
      return res.status(result.status).json({ message, accountCreated: !isResend });
    }

    return res.json({
      message: isResend ? "OTP sent." : "Account created. Enter the code we emailed you.",
      challengeId: result.challengeId,
      accountCreated: !isResend,
    });
  } catch (err) {
    if (err?.code === 11000) {
      return res.status(400).json({
        message: "An account with that email already exists. Please sign in.",
      });
    }
    console.error("Signup OTP request error:", err);
    return res.status(500).json({ message: "Server error while creating your account." });
  }
});

// Verifies the sign-up code and logs the user in.
app.post("/api/users/register/otp/verify", requireDb, async (req, res) => {
  try {
    const fields = readSignupFields(req.body);
    const { email } = fields;
    const otp = String(req.body?.otp || "").trim();
    const challengeId = String(req.body?.challengeId || "").trim();

    if (!email || !otp || !challengeId) {
      return res.status(400).json({ message: "email, otp, and challengeId are required." });
    }

    const existing = await User.findOne({ email });
    if (existing && existing.emailVerified !== false) {
      return res.status(400).json({ message: "This email is already verified. Please sign in." });
    }
    if (!existing) {
      // Older app versions create the account only at this step.
      const error = signupValidationError(fields);
      if (error) return res.status(400).json({ message: error });
    }

    const check = await verifyOtp({ email, purpose: "signup", otp, challengeId });
    if (!check.ok) {
      return res.status(check.status).json({ message: check.message });
    }

    let user = existing;
    if (user) {
      user.emailVerified = true;
      await user.save();
    } else {
      user = await User.create({
        email,
        password: await bcrypt.hash(fields.password, 10),
        firstName: fields.firstName,
        lastName: fields.lastName,
        phone: fields.phone,
        emailVerified: true,
      });
    }

    return res.status(201).json({
      _id: user._id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      phone: user.phone,
      user: userPublic(user.toObject()),
      token: generateToken(user._id),
    });
  } catch (err) {
    console.error("Signup OTP verify error:", err);
    return res.status(500).json({ message: "Server error during OTP registration." });
  }
});

app.post("/api/users/login", requireDb, async (req, res) => {
  try {
    const email = normalizeEmail(req.body?.email);
    const password = String(req.body?.password || "");
    const deviceToken = String(req.body?.deviceToken || "").trim();

    if (!email || !password) {
      return res.status(400).json({ message: "Email and password are required." });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: "Invalid email or password." });
    }

    const match = await bcrypt.compare(password, user.password);
    if (!match) {
      return res.status(400).json({ message: "Invalid email or password." });
    }

    if (deviceToken) {
      const trusted = await TrustedDevice.findOne({
        userId: user._id,
        tokenHash: hashDeviceToken(deviceToken),
        expiresAt: { $gt: new Date() },
      });
      if (trusted) {
        return res.json({
          _id: user._id,
          email: user.email,
          firstName: user.firstName,
          lastName: user.lastName,
          token: generateToken(user._id),
        });
      }
    }

    const result = await createAndSendOtp({ email, purpose: "login" });
    if (!result.ok) {
      return res.status(result.status).json({ message: result.message });
    }

    return res.json({
      message: "OTP sent to your email. Verify to continue.",
      challengeId: result.challengeId,
    });
  } catch (err) {
    console.error("Login error:", err);
    return res.status(500).json({ message: "Server error during login." });
  }
});

app.post("/api/users/login/otp/request", requireDb, async (req, res) => {
  try {
    const email = normalizeEmail(req.body?.email);
    if (!email) {
      return res.status(400).json({ message: "email is required." });
    }

    const user = await User.findOne({ email }).select("_id").lean();
    if (!user) {
      return res.status(400).json({ message: "No account found for that email." });
    }

    const result = await createAndSendOtp({ email, purpose: "login" });
    if (!result.ok) {
      return res.status(result.status).json({ message: result.message });
    }

    return res.json({ message: "OTP sent.", challengeId: result.challengeId });
  } catch (err) {
    console.error("Login OTP request error:", err);
    return res.status(500).json({ message: "Server error while sending OTP." });
  }
});

app.post("/api/users/login/otp/verify", requireDb, async (req, res) => {
  try {
    const email = normalizeEmail(req.body?.email);
    const otp = String(req.body?.otp || "").trim();
    const challengeId = String(req.body?.challengeId || "").trim();
    const rememberDevice = Boolean(req.body?.rememberDevice);

    if (!email || !otp || !challengeId) {
      return res.status(400).json({ message: "email, otp, and challengeId are required." });
    }

    const check = await verifyOtp({ email, purpose: "login", otp, challengeId });
    if (!check.ok) {
      return res.status(check.status).json({ message: check.message });
    }

    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: "No account found for that email." });
    }
    if (user.emailVerified === false) {
      // A login code also proves the user owns this email.
      user.emailVerified = true;
      await user.save();
    }

    const response = {
      _id: user._id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      token: generateToken(user._id),
    };

    if (rememberDevice) {
      const deviceToken = generateDeviceToken();
      await TrustedDevice.create({
        userId: user._id,
        tokenHash: hashDeviceToken(deviceToken),
        expiresAt: new Date(Date.now() + DEVICE_TRUST_TTL_MS),
      });
      response.deviceToken = deviceToken;
    }

    return res.json(response);
  } catch (err) {
    console.error("Login OTP verify error:", err);
    return res.status(500).json({ message: "Server error during OTP login." });
  }
});

app.post("/api/users/password/reset/otp/request", requireDb, async (req, res) => {
  try {
    const email = normalizeEmail(req.body?.email);
    if (!email) {
      return res.status(400).json({ message: "email is required." });
    }

    const user = await User.findOne({ email }).select("_id").lean();
    if (!user) {
      return res.status(400).json({ message: "No account found for that email." });
    }

    const result = await createAndSendOtp({ email, purpose: "reset_password" });
    if (!result.ok) {
      return res.status(result.status).json({ message: result.message });
    }

    return res.json({ message: "OTP sent.", challengeId: result.challengeId });
  } catch (err) {
    console.error("Reset OTP request error:", err);
    return res.status(500).json({ message: "Server error while sending OTP." });
  }
});

app.post("/api/users/password/reset/otp/confirm", requireDb, async (req, res) => {
  try {
    const email = normalizeEmail(req.body?.email);
    const otp = String(req.body?.otp || "").trim();
    const challengeId = String(req.body?.challengeId || "").trim();

    if (!email || !otp || !challengeId) {
      return res.status(400).json({ message: "email, otp, and challengeId are required." });
    }

    const check = await verifyOtp({
      email,
      purpose: "reset_password",
      otp,
      challengeId,
    });
    if (!check.ok) {
      return res.status(check.status).json({ message: check.message });
    }

    return res.json({
      message: "Code confirmed.",
      resetToken: generatePasswordResetToken(email),
    });
  } catch (err) {
    console.error("Reset OTP confirm error:", err);
    return res.status(500).json({ message: "Server error while confirming code." });
  }
});

app.post("/api/users/password/reset/complete", requireDb, async (req, res) => {
  try {
    const resetToken = String(req.body?.resetToken || "").trim();
    const newPassword = String(req.body?.newPassword || "");

    if (!resetToken || !newPassword) {
      return res.status(400).json({ message: "resetToken and newPassword are required." });
    }
    const weak = passwordError(newPassword);
    if (weak) return res.status(400).json({ message: weak });

    let decoded;
    try {
      decoded = jwt.verify(resetToken, JWT_SECRET);
    } catch (_err) {
      return res.status(400).json({ message: "Invalid or expired reset token." });
    }

    if (decoded?.typ !== "password_reset" || !decoded?.email) {
      return res.status(400).json({ message: "Invalid reset token." });
    }

    const email = normalizeEmail(decoded.email);
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(400).json({ message: "No account found for that email." });
    }

    user.password = await bcrypt.hash(newPassword, 10);
    await user.save();

    return res.json({ message: "Password reset successful." });
  } catch (err) {
    console.error("Reset password complete error:", err);
    return res.status(500).json({ message: "Server error while resetting password." });
  }
});

// Current user profile
app.get("/api/me", requireDb, requireAuth, async (req, res) => {
  return res.json({ user: userPublic(req.user) });
});

app.put("/api/me", requireDb, requireAuth, async (req, res) => {
  try {
    const body = req.body ?? {};
    const patch = {};
    for (const k of [
      "firstName",
      "lastName",
      "headline",
      "location",
      "phone",
      "portfolioUrl",
      "bio",
      "avatarUrl",
    ]) {
      if (body[k] !== undefined) patch[k] = String(body[k] ?? "").trim();
    }
    if (body.skills !== undefined || body.skillLevels !== undefined) {
      const current = readStoredSkills(req.user);
      let names = current.names;
      if (Array.isArray(body.skills)) {
        names = body.skills.map((s) => String(s).trim()).filter(Boolean);
      } else if (typeof body.skills === "string") {
        names = body.skills
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean);
      }
      const levels =
        body.skillLevels && typeof body.skillLevels === "object"
          ? body.skillLevels
          : current.levels;
      // Stores skills grouped, each as "<name> (<level>/10)".
      Object.assign(patch, toStoredSkills(names, levels));
    }
    if (body.education !== undefined) {
      const normalizeItem = (it) => ({
        degree: String(it?.degree ?? "").trim(),
        school: String(it?.school ?? "").trim(),
        years: String(it?.years ?? "").trim(),
      });
      if (Array.isArray(body.education)) {
        patch.education = body.education
          .map(normalizeItem)
          .filter((it) => it.degree || it.school || it.years);
      } else if (typeof body.education === "string") {
        // Convenience: newline separated lines "Degree | School | Years"
        patch.education = body.education
          .split("\n")
          .map((l) => l.trim())
          .filter(Boolean)
          .map((line) => {
            const parts = line.split("|").map((p) => p.trim());
            return normalizeItem({
              degree: parts[0] ?? "",
              school: parts[1] ?? "",
              years: parts[2] ?? "",
            });
          })
          .filter((it) => it.degree || it.school || it.years);
      }
    }
    if (body.experience !== undefined) {
      const normalizeItem = (it) => ({
        year: String(it?.year ?? "").trim(),
        title: String(it?.title ?? "").trim(),
        company: String(it?.company ?? "").trim(),
        description: String(it?.description ?? "").trim(),
      });
      if (Array.isArray(body.experience)) {
        patch.experience = body.experience
          .map(normalizeItem)
          .filter((it) => it.year || it.title || it.company || it.description);
      } else if (typeof body.experience === "string") {
        // Convenience: newline separated lines "Year | Title | Company | Description"
        patch.experience = body.experience
          .split("\n")
          .map((l) => l.trim())
          .filter(Boolean)
          .map((line) => {
            const parts = line.split("|").map((p) => p.trim());
            return normalizeItem({
              year: parts[0] ?? "",
              title: parts[1] ?? "",
              company: parts[2] ?? "",
              description: parts[3] ?? "",
            });
          })
          .filter((it) => it.year || it.title || it.company || it.description);
      }
    }
    if (body.profile !== undefined && body.profile && typeof body.profile === "object") {
      const existingProfile = (req.user.profile && typeof req.user.profile === "object")
        ? req.user.profile
        : {};
      // Assessment results are graded and saved only by
      // /api/assessments/:id/submit, so clients can't overwrite them (e.g.
      // to fake a passed assessment). `removeResume` is a flag, not data.
      const {
        skillAssessments: _ignoredAssessments,
        assessmentRecords: _ignoredRecords,
        removeResume,
        ...incoming
      } = body.profile;
      patch.profile = { ...existingProfile, ...incoming };
      if (removeResume === true || body.removeResume === true) {
        patch.profile.resume = null;
      }
    }
    if (patch.skills) {
      // Remove the old-format fields (no longer in the schema, so this
      // goes straight to the collection).
      await User.collection.updateOne(
        { _id: req.user._id },
        { $unset: { skillLevels: "", skillGroups: "", skillNames: "" } }
      );
    }
    const updated = await User.findByIdAndUpdate(req.user._id, patch, {
      new: true,
    }).lean();
    return res.json({ user: userPublic(updated) });
  } catch (err) {
    console.error("Update profile error:", err);
    return res.status(500).json({ message: "Could not update profile." });
  }
});

// Apply to a job
app.post("/api/applications", requireDb, requireAuth, async (req, res) => {
  try {
    const { jobId, jobSnapshot } = req.body ?? {};
    if (!jobId || String(jobId).trim() === "") {
      return res.status(400).json({ message: "jobId is required." });
    }
    const jobExists =
      mongoose.Types.ObjectId.isValid(jobId) &&
      (await Job.exists({ _id: jobId }));
    if (!jobExists) {
      return res.status(404).json({ message: "This job is no longer available." });
    }

    const snapshot = jobSnapshot && typeof jobSnapshot === "object" ? jobSnapshot : {};
    const rawChallenge = req.body?.codingChallenge;
    const codingChallenge =
      rawChallenge && typeof rawChallenge === "object"
        ? {
            questionId: String(rawChallenge.questionId ?? ""),
            language: String(rawChallenge.language ?? ""),
            selectedAnswer: String(rawChallenge.selectedAnswer ?? ""),
            correct: rawChallenge.correct === true,
            timeTakenSeconds: Math.max(0, Number(rawChallenge.timeTakenSeconds) || 0),
            answeredAt: rawChallenge.answeredAt ? new Date(rawChallenge.answeredAt) : new Date(),
          }
        : null;

    const existing = await Application.findOne({
      userId: req.user._id,
      jobId: String(jobId),
    });

    if (existing) {
      if (existing.status === "Withdrawn") {
        existing.status = "Applied";
        existing.withdrawnAt = null;
        existing.jobSnapshot = {
          title: String(snapshot.title ?? existing.jobSnapshot?.title ?? ""),
          company: String(snapshot.company ?? existing.jobSnapshot?.company ?? ""),
          location: String(snapshot.location ?? existing.jobSnapshot?.location ?? ""),
          salary: String(snapshot.salary ?? existing.jobSnapshot?.salary ?? ""),
          jobType: String(snapshot.jobType ?? existing.jobSnapshot?.jobType ?? ""),
          postedDate: String(snapshot.postedDate ?? existing.jobSnapshot?.postedDate ?? ""),
          matchPercentage: Number(snapshot.matchPercentage ?? existing.jobSnapshot?.matchPercentage ?? 0) || 0,
        };
        if (codingChallenge) existing.codingChallenge = codingChallenge;
        existing.statusHistory.push({ status: "Applied", at: new Date() });
        const saved = await existing.save();
        return res.status(200).json({ application: saved, reactivated: true });
      } else {
        return res.status(409).json({ message: "You already applied to this job." });
      }
    }

    const doc = await Application.create({
      userId: req.user._id,
      jobId: String(jobId),
      jobSnapshot: {
        title: String(snapshot.title ?? ""),
        company: String(snapshot.company ?? ""),
        location: String(snapshot.location ?? ""),
        salary: String(snapshot.salary ?? ""),
        jobType: String(snapshot.jobType ?? ""),
        postedDate: String(snapshot.postedDate ?? ""),
        matchPercentage: Number(snapshot.matchPercentage ?? 0) || 0,
      },
      status: "Applied",
      statusHistory: [{ status: "Applied", at: new Date() }],
      codingChallenge,
    });
    return res.status(201).json({ application: doc });
  } catch (err) {
    if (err?.code === 11000) {
      return res.status(409).json({ message: "You already applied to this job." });
    }
    console.error("Apply error:", err);
    return res.status(500).json({ message: "Could not apply to job." });
  }
});

app.get("/api/applications", requireDb, requireAuth, async (req, res) => {
  try {
    const apps = await Application.find({ userId: req.user._id })
      .sort({ createdAt: -1 })
      .lean();
    return res.json({ applications: apps });
  } catch (err) {
    console.error("List applications error:", err);
    return res.status(500).json({ message: "Could not load applications." });
  }
});

app.patch("/api/applications/:id", requireDb, requireAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body ?? {};
    const next = String(status ?? "").trim();
    if (!next) return res.status(400).json({ message: "status is required." });
    if (!mongoose.Types.ObjectId.isValid(id)) {
      return res.status(404).json({ message: "Application not found." });
    }

    if (next !== "Withdrawn") {
      return res.status(403).json({
        message: "Applicants can only withdraw their own applications.",
      });
    }

    const existing = await Application.findOne({
      _id: id,
      userId: req.user._id,
    });
    if (!existing) return res.status(404).json({ message: "Application not found." });

    if (existing.status === "Hired") {
      return res.status(400).json({
        message: "Cannot withdraw an application once hired.",
      });
    }
    if (existing.status === "Rejected") {
      return res.status(400).json({
        message: "Cannot withdraw a rejected application.",
      });
    }
    if (existing.status === "Withdrawn") {
      return res.status(400).json({
        message: "Application is already withdrawn.",
      });
    }
    existing.withdrawnAt = new Date();

    existing.status = next;
    existing.statusHistory.push({ status: next, at: new Date() });
    const appDoc = await existing.save();
    return res.json({ application: appDoc.toObject() });
  } catch (err) {
    console.error("Update application error:", err);
    return res.status(500).json({ message: "Could not update application." });
  }
});

async function main() {
  const server = app.listen(PORT, "0.0.0.0", () => {
    console.log(`API listening on http://0.0.0.0:${PORT}`);
  });
  server.on("error", (err) => {
    if (err?.code === "EADDRINUSE") {
      console.error(
        `Port ${PORT} is already in use. Set a different PORT in your .env (e.g. PORT=${
          PORT + 1
        }) or stop the other process using it.`
      );
      process.exit(1);
    }
    console.error("Server error:", err);
    process.exit(1);
  });

  async function connectWithRetry(attempt = 1) {
    try {
      await mongoose.connect(MONGODB_URI, {
        serverSelectionTimeoutMS: 8000,
      });
      console.log("Connected to MongoDB");
    } catch (err) {
      const delayMs = Math.min(30000, 1000 * Math.pow(2, attempt - 1));
      console.error(
        `MongoDB connection failed (attempt ${attempt}). Retrying in ${Math.round(
          delayMs / 1000
        )}s...`,
        err?.message ?? err
      );
      setTimeout(() => connectWithRetry(attempt + 1), delayMs);
    }
  }

  connectWithRetry();
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
