import mongoose from "mongoose";

const questionSchema = new mongoose.Schema(
  {
    questionId: { type: String },
    prompt: { type: String, required: true },
    type: { type: String, default: "multiple_choice" },
    options: { type: [String], default: [] },
    correctAnswer: { type: String, required: true },
    explanation: { type: String, default: "" },
    competency: { type: String, default: "" },
    skillType: { type: String, default: "Functional Competency" },
    difficulty: { type: String, default: "Mid-Level" },
    points: { type: Number, default: 5 },
    timeLimitSeconds: { type: Number, default: 120 },
    isCustom: { type: Boolean, default: false },
  },
  { _id: true, timestamps: false }
);

const assessmentSchema = new mongoose.Schema(
  {
    roleId: { type: String, required: true, index: true },
    roleTitle: { type: String, required: true },
    title: { type: String, required: true },
    track: { type: String, required: true, index: true },
    description: { type: String, default: "" },
    isPublished: { type: Boolean, default: true, index: true },
    passingScorePercentage: { type: Number, default: 70 },
    timeLimitMinutes: { type: Number, default: 25 },
    questions: { type: [questionSchema], default: [] },
    createdBy: { type: mongoose.Schema.Types.ObjectId, ref: "EmployerAccount" },
  },
  { timestamps: true, collection: "assessments", strict: false }
);

const Assessment =
  mongoose.models.Assessment || mongoose.model("Assessment", assessmentSchema);

export default Assessment;
