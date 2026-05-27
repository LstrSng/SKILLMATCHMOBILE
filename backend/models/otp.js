import mongoose from "mongoose";

const otpSchema = new mongoose.Schema(
  {
    email: { type: String, required: true, index: true },
    purpose: { type: String, required: true, index: true },
    challengeId: { type: String, required: true, index: true },
    codeHash: { type: String, required: true },
    expiresAt: { type: Date, required: true, index: true },
    consumedAt: { type: Date, default: null },
    attemptCount: { type: Number, default: 0 },
  },
  { timestamps: true, collection: "otps" }
);

otpSchema.index({ email: 1, purpose: 1, createdAt: -1 });
otpSchema.index({ email: 1, purpose: 1, challengeId: 1, createdAt: -1 });
otpSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });

const Otp = mongoose.model("Otp", otpSchema);

export default Otp;
