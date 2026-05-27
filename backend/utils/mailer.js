import nodemailer from "nodemailer";

let transporterPromise = null;

function parseBoolean(value, defaultValue = false) {
  if (value === undefined) return defaultValue;
  return String(value).trim().toLowerCase() === "true";
}

async function getTransporter() {
  if (transporterPromise) return transporterPromise;

  transporterPromise = (async () => {
    const host = String(process.env.SMTP_HOST || "").trim();
    const port = Number(process.env.SMTP_PORT || 0);
    const user = String(process.env.SMTP_USER || "").trim();
    const pass = String(process.env.SMTP_PASS || "").trim();

    if (!host || !port || !user || !pass) {
      throw new Error("Missing SMTP configuration in environment.");
    }

    const transporter = nodemailer.createTransport({
      host,
      port,
      secure: parseBoolean(process.env.SMTP_SECURE, port === 465),
      auth: { user, pass },
      logger: parseBoolean(process.env.MAIL_DEBUG, false),
      debug: parseBoolean(process.env.MAIL_DEBUG, false),
    });

    await transporter.verify();
    return transporter;
  })().catch((err) => {
    transporterPromise = null;
    throw err;
  });

  return transporterPromise;
}

export async function sendMail({ to, subject, text, html }) {
  const transporter = await getTransporter();
  return transporter.sendMail({
    from: process.env.MAIL_FROM || process.env.SMTP_USER,
    to,
    subject,
    text,
    html,
  });
}
