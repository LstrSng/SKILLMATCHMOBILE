import mongoose from "mongoose";

const applicationSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "MobileUser",
      required: true,
      index: true,
    },
    jobId: { type: String, required: true, index: true },

    // Snapshot so the app can render even if job listing changes.
    jobSnapshot: {
      title: { type: String, default: "" },
      company: { type: String, default: "" },
      location: { type: String, default: "" },
      salary: { type: String, default: "" },
      jobType: { type: String, default: "" },
      postedDate: { type: String, default: "" },
      matchPercentage: { type: Number, default: 0 },
    },

    status: {
      type: String,
      enum: [
        "Applied",
        "Screening",
        "Interview",
        "Offer",
        "Rejected",
        "Withdrawn",
      ],
      default: "Applied",
      index: true,
    },
    statusHistory: {
      type: [
        {
          status: { type: String, required: true },
          at: { type: Date, default: Date.now },
        },
      ],
      default: [],
    },
    withdrawnAt: { type: Date, default: null },
  },
  { timestamps: true, collection: "applications" }
);

applicationSchema.index({ userId: 1, jobId: 1 }, { unique: true });

const Application =
  mongoose.models.Application || mongoose.model("Application", applicationSchema);

export default Application;

