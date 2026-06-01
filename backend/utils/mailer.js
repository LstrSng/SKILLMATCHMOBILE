import { Resend } from "resend";

let resendClient = null;

function parseBoolean(value, defaultValue = false) {
  if (value === undefined) return defaultValue;
  return String(value).trim().toLowerCase() === "true";
}

function getResendClient() {
  if (resendClient) return resendClient;

  const apiKey = String(process.env.RESEND_API_KEY || "").trim();
  if (!apiKey) {
    throw new Error("Missing RESEND_API_KEY in environment.");
  }

  resendClient = new Resend(apiKey);
  return resendClient;
}

export async function sendMail({ to, subject, text, html }) {
  const resend = getResendClient();
  const from = String(process.env.MAIL_FROM || "").trim();

  if (!from) {
    throw new Error("Missing MAIL_FROM in environment.");
  }

  const payload = {
    from,
    to: Array.isArray(to) ? to : [to],
    subject,
  };

  if (text) payload.text = text;
  if (html) payload.html = html;

  const result = await resend.emails.send(payload);
  if (result?.error) {
    throw new Error(result.error.message || "Resend email send failed.");
  }

  if (parseBoolean(process.env.MAIL_DEBUG, false)) {
    console.log("[mail] resend accepted", {
      id: result?.data?.id,
      to: payload.to,
      subject,
    });
  }

  return result;
}
