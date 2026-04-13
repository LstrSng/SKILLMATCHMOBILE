/**
 * Pick first non-empty value from object for any of the given keys.
 */
export function pickFirst(obj, keys) {
  if (!obj || typeof obj !== "object") return null;
  for (const k of keys) {
    const v = obj[k];
    if (v === undefined || v === null) continue;
    if (typeof v === "string" && v.trim() === "") continue;
    return v;
  }
  return null;
}

function toStringArray(val) {
  if (val == null) return [];
  if (Array.isArray(val)) return val.map((x) => String(x).trim()).filter(Boolean);
  if (typeof val === "string" && val.trim() !== "") return [val.trim()];
  return [];
}

function coalesceStringArray(obj, keys) {
  if (!obj || typeof obj !== "object") return [];
  for (const k of keys) {
    const arr = toStringArray(obj[k]);
    if (arr.length) return arr;
  }
  return [];
}

function numOrDefault(v, fallback) {
  if (typeof v === "number" && !Number.isNaN(v)) return Math.round(v);
  if (typeof v === "string" && v.trim() !== "") {
    const n = Number(v);
    if (!Number.isNaN(n)) return Math.round(n);
  }
  return fallback;
}

/**
 * Map a MongoDB job document to the JSON shape expected by the mobile app.
 */
export function normalizeJobDoc(d) {
  const id = d._id != null ? String(d._id) : "";

  const title =
    pickFirst(d, ["title", "jobTitle", "name", "role", "position", "job_name"]) ||
    "Untitled role";

  const company =
    pickFirst(d, ["company", "companyName", "employer", "organization", "org"]) || "";

  const location =
    pickFirst(d, ["location", "place", "city", "region"]) || "";

  const salary =
    pickFirst(d, ["salary", "salaryRange", "compensation", "pay"]) || "";

  const jobType =
    pickFirst(d, ["jobType", "type", "employmentType", "workType", "schedule"]) ||
    "";

  const description =
    pickFirst(d, ["description", "details", "summary", "about"]) || "";

  let matchedSkills = coalesceStringArray(d, [
    "matchedSkills",
    "matched",
    "skillsMatch",
    "matchingSkills",
  ]);
  let unmatchedSkills = coalesceStringArray(d, [
    "unmatchedSkills",
    "unmatched",
    "missingSkills",
    "gapSkills",
  ]);

  if (matchedSkills.length === 0 && unmatchedSkills.length === 0) {
    matchedSkills = coalesceStringArray(d, [
      "skills",
      "requiredSkills",
      "requirements",
      "techStack",
    ]);
  }

  const matchPercentage = numOrDefault(
    pickFirst(d, ["matchPercentage", "matchScore", "score", "match"]),
    0
  );

  const postedDate =
    pickFirst(d, ["postedDate", "posted", "datePosted"]) ||
    formatPostedFromTimestamps(d);

  return {
    id,
    title: String(title),
    company: String(company),
    location: String(location),
    salary: String(salary),
    jobType: String(jobType),
    description: String(description),
    matchPercentage,
    matchedSkills,
    unmatchedSkills,
    postedDate: String(postedDate),
  };
}

function formatPostedFromTimestamps(d) {
  const raw = d.createdAt || d.postedAt || d.updatedAt;
  if (!raw) return "";
  try {
    const date = raw instanceof Date ? raw : new Date(raw);
    if (Number.isNaN(date.getTime())) return "";
    return _relativeTime(date);
  } catch {
    return "";
  }
}

function _relativeTime(date) {
  const now = new Date();
  const diffMs = now - date;
  const days = Math.floor(diffMs / (1000 * 60 * 60 * 24));
  if (days <= 0) return "Posted today";
  if (days === 1) return "1 day ago";
  if (days < 7) return `${days} days ago`;
  const weeks = Math.floor(days / 7);
  if (weeks < 4) return `${weeks} week${weeks === 1 ? "" : "s"} ago`;
  return date.toLocaleDateString();
}
