import mongoose from "mongoose";

const employerAccountSchema = new mongoose.Schema(
  {},
  { strict: false, collection: "users" }
);

const EmployerAccount =
  mongoose.models.EmployerAccount ||
  mongoose.model("EmployerAccount", employerAccountSchema);

export default EmployerAccount;