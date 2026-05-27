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
import { normalizeJobDoc } from "./jobNormalize.js";
import { generateNumericOtp, hashOtp } from "./utils/otp.js";
import { sendMail } from "./utils/mailer.js";

const DEFAULT_PORT = 5002;
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
app.use(express.json({ limit: "8mb" }));

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
      message: "Failed to send OTP email. Check server logs.",
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
    skills: Array.isArray(u.skills) ? u.skills : [],
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

// Mobile match analytics: compare applicant skills vs. job skills
app.get(
  "/api/mobile/match/:applicantId/:jobId",
  requireDb,
  requireAuth,
  async (req, res) => {
    try {
      const { applicantId, jobId } = req.params ?? {};

      if (!applicantId || !jobId) {
        return res.status(400).json({ message: "Missing applicantId or jobId." });
      }

      // Load job and applicant
      const [jobDoc, applicant] = await Promise.all([
        Job.findById(jobId).lean(),
        User.findById(applicantId).lean(),
      ]);

      if (!jobDoc) return res.status(404).json({ message: "Job not found." });
      if (!applicant) return res.status(404).json({ message: "Applicant not found." });

      const job = normalizeJobDoc(jobDoc);

      // Collect job skill candidates
      const jobSkills = Array.isArray(job.matchedSkills) && job.matchedSkills.length
        ? job.matchedSkills
        : Array.isArray(job.unmatchedSkills) && job.unmatchedSkills.length
        ? [...job.matchedSkills, ...job.unmatchedSkills]
        : [];

      const applicantSkills = Array.isArray(applicant.skills)
        ? applicant.skills.map((s) => String(s).trim()).filter(Boolean)
        : [];

      const lowerApplicant = new Set(applicantSkills.map((s) => s.toLowerCase()));

      const matchedSkills = [];
      const missingSkills = [];
      for (const s of jobSkills) {
        const raw = String(s ?? "").trim();
        if (!raw) continue;
        if (lowerApplicant.has(raw.toLowerCase())) matchedSkills.push(raw);
        else missingSkills.push(raw);
      }

      const total = matchedSkills.length + missingSkills.length;
      const matchScore = total > 0 ? Math.round((matchedSkills.length / total) * 100) : (Number(job.matchPercentage) || 0);

      let recommendation = "No recommendation available.";
      if (matchScore >= 80) recommendation = "Great fit — you match most required skills.";
      else if (matchScore >= 50) recommendation = "Good fit — consider learning a few missing skills to improve your chances.";
      else if (matchScore > 0) recommendation = `Low match — consider gaining experience in ${missingSkills.slice(0,3).join(', ')}.`;

      return res.json({
        jobTitle: job.title || "",
        matchScore,
        matchedSkills,
        missingSkills,
        recommendation,
      });
    } catch (err) {
      console.error("Match analytics error:", err);
      return res.status(500).json({ message: "Could not compute match analytics." });
    }
  }
);

// Jobs stored in MongoDB (collection: JOBS_COLLECTION, default `jobs`)
app.get("/api/jobs", requireDb, async (req, res) => {
  try {
    if (mongoose.connection.readyState !== 1) {
      return res
        .status(503)
        .json({ message: "Database is not connected yet." });
    }

    const raw = await Job.find({})
      .sort({ _id: -1 })
      .limit(JOBS_QUERY_LIMIT)
      .lean();

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

    const applicantSkillsSet = applicant && Array.isArray(applicant.skills)
      ? new Set(applicant.skills.map((s) => String(s).trim().toLowerCase()))
      : null;

    const jobs = raw.map((doc) => {
      const job = normalizeJobDoc(doc);

      if (applicantSkillsSet) {
        const jobSkills = (Array.isArray(job.matchedSkills) && job.matchedSkills.length)
          ? job.matchedSkills
          : (Array.isArray(job.unmatchedSkills) && job.unmatchedSkills.length)
            ? [...job.matchedSkills, ...job.unmatchedSkills]
            : [];

        const matchedSkills = [];
        const missingSkills = [];
        for (const s of jobSkills) {
          const rawSkill = String(s ?? "").trim();
          if (!rawSkill) continue;
          if (applicantSkillsSet.has(rawSkill.toLowerCase())) matchedSkills.push(rawSkill);
          else missingSkills.push(rawSkill);
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

// OTP-backed auth flows
app.post("/api/users/register", requireDb, async (req, res) => {
  return res.status(400).json({
    message:
      "Registration requires OTP verification. Use /api/users/register/otp/request then /api/users/register/otp/verify.",
  });
});

app.post("/api/users/register/otp/request", requireDb, async (req, res) => {
  try {
    const email = normalizeEmail(req.body?.email);
    if (!email) {
      return res.status(400).json({ message: "email is required." });
    }
    if (!isValidEmail(email)) {
      return res.status(400).json({ message: "Please enter a valid email address." });
    }

    const existing = await User.findOne({ email }).select("_id").lean();
    if (existing) {
      return res.status(400).json({ message: "User already exists with that email." });
    }

    const result = await createAndSendOtp({ email, purpose: "signup" });
    if (!result.ok) {
      return res.status(result.status).json({ message: result.message });
    }

    return res.json({ message: "OTP sent.", challengeId: result.challengeId });
  } catch (err) {
    console.error("Signup OTP request error:", err);
    return res.status(500).json({ message: "Server error while sending OTP." });
  }
});

app.post("/api/users/register/otp/verify", requireDb, async (req, res) => {
  try {
    const firstName = String(req.body?.firstName || "").trim();
    const lastName = String(req.body?.lastName || "").trim();
    const email = normalizeEmail(req.body?.email);
    const password = String(req.body?.password || "");
    const otp = String(req.body?.otp || "").trim();
    const challengeId = String(req.body?.challengeId || "").trim();

    if (!firstName || !lastName || !email || !password || !otp || !challengeId) {
      return res.status(400).json({ message: "Missing required fields." });
    }
    if (!isValidEmail(email)) {
      return res.status(400).json({ message: "Please enter a valid email address." });
    }
    if (password.length < 8) {
      return res.status(400).json({ message: "Password must be at least 8 characters." });
    }

    const existing = await User.findOne({ email }).select("_id").lean();
    if (existing) {
      return res.status(400).json({ message: "User already exists with that email." });
    }

    const check = await verifyOtp({ email, purpose: "signup", otp, challengeId });
    if (!check.ok) {
      return res.status(check.status).json({ message: check.message });
    }

    const passwordHash = await bcrypt.hash(password, 10);
    const user = await User.create({
      email,
      password: passwordHash,
      firstName,
      lastName,
    });

    return res.status(201).json({
      _id: user._id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
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

    return res.json({
      _id: user._id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      token: generateToken(user._id),
    });
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
    if (newPassword.length < 8) {
      return res.status(400).json({ message: "Password must be at least 8 characters." });
    }

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
    if (body.skills !== undefined) {
      if (Array.isArray(body.skills)) {
        patch.skills = body.skills.map((s) => String(s).trim()).filter(Boolean);
      } else if (typeof body.skills === "string") {
        patch.skills = body.skills
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean);
      }
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
      patch.profile = body.profile;
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

    const snapshot = jobSnapshot && typeof jobSnapshot === "object" ? jobSnapshot : {};
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

    const allowed = new Set([
      "Applied",
      "Screening",
      "Interview",
      "Offer",
      "Rejected",
      "Withdrawn",
    ]);
    if (!allowed.has(next)) {
      return res.status(400).json({ message: "Invalid status." });
    }

    const update = {
      status: next,
      $push: { statusHistory: { status: next, at: new Date() } },
    };
    if (next === "Withdrawn") update.withdrawnAt = new Date();

    const appDoc = await Application.findOneAndUpdate(
      { _id: id, userId: req.user._id },
      update,
      { new: true }
    ).lean();
    if (!appDoc) return res.status(404).json({ message: "Application not found." });
    return res.json({ application: appDoc });
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
