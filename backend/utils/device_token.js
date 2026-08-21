import crypto from "crypto";

export function generateDeviceToken() {
  return crypto.randomBytes(32).toString("hex");
}

export function hashDeviceToken(token) {
  return crypto.createHash("sha256").update(String(token)).digest("hex");
}
