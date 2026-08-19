import mongoose from "mongoose";

// Employer/company accounts live in the `users` collection, owned by a
// separate (non-mobile) part of the system. We only need to read a couple of
// fields from it here (to backfill a job's company name), so this stays
// `strict: false` rather than duplicating that schema.
const employerAccountSchema = new mongoose.Schema(
  {},
  { strict: false, collection: "users" }
);

const EmployerAccount =
  mongoose.models.EmployerAccount ||
  mongoose.model("EmployerAccount", employerAccountSchema);

export default EmployerAccount;