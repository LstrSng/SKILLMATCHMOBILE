import mongoose from "mongoose";

// Collection name in MongoDB (override if your jobs live elsewhere, e.g. `job_listings`).
const JOBS_COLLECTION = process.env.JOBS_COLLECTION || "jobs";

// `strict: false` allows reading documents that use slightly different field names;
// the `/api/jobs` handler normalizes them to a stable JSON shape for the app.
const jobSchema = new mongoose.Schema(
  {},
  { strict: false, collection: JOBS_COLLECTION }
);

const Job = mongoose.models.JobListing || mongoose.model("JobListing", jobSchema);

export default Job;
