import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import path from "path";

// Same grouping as the mobile app's profile screen (lib/services/
// job_roles_data.dart → categorizeSkill), using the PSF-SDS catalogs:
// enabling (soft) skills, functional (job-function) skills, and everything
// else — languages, frameworks, tools, custom skills — as tech stack.

const dataPath = path.join(
  path.dirname(fileURLToPath(import.meta.url)),
  "..",
  "data",
  "psf_sds_data.json"
);

/** "Business Needs Analysis Level 2" -> "Business Needs Analysis". */
export function plainSkillName(skill) {
  return String(skill ?? "")
    .trim()
    .replace(/^-?\s*Level\s*\d+(?:-\d+)?\s*/i, "")
    .replace(/\s*Level\s*\d+(?:-\d+)?\s*$/i, "")
    .replace(/\s*(Basic|Intermediate|Advanced)\s*$/i, "")
    .trim();
}

// Soft skills the app's skill picker offers that aren't in the catalog.
const EXTRA_ENABLING = [
  "leadership",
  "time management",
  "customer service",
  "creativity",
  "attention to detail",
  "public speaking",
  "negotiation",
  "conflict resolution",
];

let catalogs = null;
function loadCatalogs() {
  if (catalogs) return catalogs;
  const data = JSON.parse(readFileSync(dataPath, "utf8"));
  const keys = (list) =>
    new Set(
      (list ?? [])
        .map((e) => plainSkillName(e?.name).toLowerCase())
        .filter(Boolean)
    );
  catalogs = {
    functional: keys(data.functionalSkillCatalog),
    enabling: new Set([...keys(data.enablingSkillCatalog), ...EXTRA_ENABLING]),
  };
  return catalogs;
}

/** "techStack" | "functional" | "enabling" for one skill. */
export function categorizeSkill(skill) {
  const { functional, enabling } = loadCatalogs();
  const key = plainSkillName(skill).toLowerCase();
  if (enabling.has(key)) return "enabling";
  if (functional.has(key)) return "functional";
  return "techStack";
}

const GROUPS = ["techStack", "functional", "enabling"];

function validLevel(value) {
  const n = Math.round(Number(value));
  return Number.isFinite(n) && n >= 1 ? Math.min(10, n) : null;
}

/** "Figma (5/10)" -> { name: "Figma", level: 5 }; "Figma" -> level null. */
function parseStoredSkill(entry) {
  if (entry && typeof entry === "object") {
    // Older { name, level } form.
    return { name: String(entry.name ?? "").trim(), level: validLevel(entry.level) };
  }
  const text = String(entry ?? "").trim();
  const m = text.match(/^(.*?)\s*\((\d{1,2})\/10\)$/);
  return m
    ? { name: m[1].trim(), level: validLevel(m[2]) }
    : { name: text, level: null };
}

/**
 * Builds the stored form of a user's skills from a flat list of names and
 * a { name: level } map: grouped into techStack / functional / enabling,
 * each entry "<name> (<level>/10)" (or just the name when unrated).
 */
export function toStoredSkills(names, levels) {
  const seen = new Set();
  const skills = { techStack: [], functional: [], enabling: [] };
  for (const raw of Array.isArray(names) ? names : []) {
    const name = String(raw ?? "").trim();
    if (!name || seen.has(name.toLowerCase())) continue;
    seen.add(name.toLowerCase());
    const level = validLevel(
      levels && typeof levels === "object" ? levels[name] : null
    );
    skills[categorizeSkill(name)].push(level ? `${name} (${level}/10)` : name);
  }
  return { skills };
}

/**
 * Reads a stored user's skills back as a flat list of names and a
 * { name: level } map (the format the mobile app uses). Also accepts the
 * older formats: a plain array plus a `skillLevels` map, and grouped
 * { name, level } objects.
 */
export function readStoredSkills(user) {
  const stored = user?.skills;
  if (Array.isArray(stored)) {
    const names = stored.map((s) => String(s ?? "").trim()).filter(Boolean);
    const levels = {};
    for (const name of names) {
      const level = validLevel(user?.skillLevels?.[name]);
      if (level) levels[name] = level;
    }
    return { names, levels };
  }
  const names = [];
  const levels = {};
  for (const group of GROUPS) {
    for (const entry of stored?.[group] ?? []) {
      const { name, level } = parseStoredSkill(entry);
      if (!name) continue;
      names.push(name);
      if (level) levels[name] = level;
    }
  }
  return { names, levels };
}
