import "dotenv/config";
import cors from "cors";
import express from "express";
import mongoose from "mongoose";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import MobileUser from "./models/mobile_user.js";
import Job from "./models/job.js";
import Application from "./models/application.js";
import { normalizeJobDoc } from "./jobNormalize.js";

const DEFAULT_PORT = 5001;
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
app.use(express.json());

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

// Jobs stored in MongoDB (collection: JOBS_COLLECTION, default `jobs`)
app.get("/api/jobs", async (_req, res) => {
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
    const jobs = raw.map((doc) => normalizeJobDoc(doc));
    return res.json({ jobs });
  } catch (err) {
    console.error("Jobs list error:", err);
    return res.status(500).json({ message: "Could not load jobs." });
  }
});

// Same shape as your web app: POST /api/users/register | /login
app.post("/api/users/register", requireDb, async (req, res) => {
  try {
    const { firstName, lastName, email, password } = req.body ?? {};
    if (!email || !password || !firstName || !lastName) {
      return res.status(400).json({ message: "Please fill in all required fields." });
    }
    if (password.length < 8) {
      return res.status(400).json({ message: "Password must be at least 8 characters." });
    }
    const existing = await User.findOne({ email: email.toLowerCase().trim() });
    if (existing) {
      return res.status(400).json({ message: "User already exists with that email." });
    }
    const passwordHash = await bcrypt.hash(password, 10);
    const user = await User.create({
      email: email.toLowerCase().trim(),
      password: passwordHash,
      firstName: String(firstName).trim(),
      lastName: String(lastName).trim(),
    });
    return res.status(201).json({
      _id: user._id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      token: generateToken(user._id),
    });
  } catch (err) {
    console.error("Register error:", err);
    return res.status(500).json({ message: "Server error during registration." });
  }
});

app.post("/api/users/login", requireDb, async (req, res) => {
  try {
    const { email, password } = req.body ?? {};
    if (!email || !password) {
      return res.status(400).json({ message: "Email and password are required." });
    }
    const user = await User.findOne({ email: email.toLowerCase().trim() });
    if (!user) {
      return res.status(400).json({ message: "Invalid email or password." });
    }
    const match = await bcrypt.compare(password, user.password);
    if (!match) {
      return res.status(400).json({ message: "Invalid email or password." });
    }
    return res.json({
      _id: user._id,
      email: user.email,
      firstName: user.firstName,
      lastName: user.lastName,
      token: generateToken(user._id),
    });
  } catch (err) {
    console.error("Login error:", err);
    return res.status(500).json({ message: "Server error during login." });
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
