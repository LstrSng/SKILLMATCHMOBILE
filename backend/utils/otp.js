import crypto from "crypto";

export function generateNumericOtp(length = 6) {
  const digits = [];
  while (digits.length < length) {
    digits.push(crypto.randomInt(0, 10));
  }
  return digits.join("");
}

export function hashOtp({ email, purpose, otp }) {
  const pepper = String(process.env.OTP_PEPPER || "");
  return crypto
    .createHash("sha256")
    .update(`${String(email).toLowerCase().trim()}|${purpose}|${otp}|${pepper}`)
    .digest("hex");
}
