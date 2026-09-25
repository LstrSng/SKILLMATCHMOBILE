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

/**
 * Builds the stored form of a user's skills from a flat list of names and
 * a { name: level } map: `skills` grouped into techStack / functional /
 * enabling as [{ name, level }], plus `skillNames` (flat list).
 */
export function toStoredSkills(names, levels) {
  const seen = new Set();
  const skills = { techStack: [], functional: [], enabling: [] };
  for (const raw of Array.isArray(names) ? names : []) {
    const name = String(raw ?? "").trim();
    if (!name || seen.has(name.toLowerCase())) continue;
    seen.add(name.toLowerCase());
    skills[categorizeSkill(name)].push({
      name,
      level: validLevel(levels && typeof levels === "object" ? levels[name] : null),
    });
  }
  return {
    skills,
    skillNames: GROUPS.flatMap((g) => skills[g].map((s) => s.name)),
  };
}

/**
 * Reads a stored user's skills back as a flat list of names and a
 * { name: level } map (the format the mobile app uses). Also accepts the
 * old format: `skills` as a plain array plus a `skillLevels` map.
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
    for (const item of stored?.[group] ?? []) {
      const name = String(item?.name ?? "").trim();
      if (!name) continue;
      names.push(name);
      const level = validLevel(item?.level);
      if (level) levels[name] = level;
    }
  }
  return { names, levels };
}
