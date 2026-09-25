// Migrates mobile users to the grouped skills format:
//   skills: { techStack, functional, enabling: ["Figma (5/10)", …] }
// from any older format (a plain array + skillLevels map, or grouped
// { name, level } objects), and removes the old skillLevels / skillGroups /
// skillNames fields. Safe to run again.
// Usage (from backend/): npm run migrate:skills
import "dotenv/config";
import mongoose from "mongoose";
import MobileUser from "../models/mobile_user.js";
import { readStoredSkills, toStoredSkills } from "../utils/skill_groups.js";

const uri = process.env.MONGODB_URI || process.env.MONGO_URI;
if (!uri) {
  console.error("Missing MONGODB_URI (or MONGO_URI) in .env");
  process.exit(1);
}

await mongoose.connect(uri);
const users = await MobileUser.collection
  .find({}, { projection: { skills: 1, skillLevels: 1, skillGroups: 1, skillNames: 1 } })
  .toArray();

const ops = [];
for (const u of users) {
  const groups = ["techStack", "functional", "enabling"];
  const hasObjects = groups.some((g) =>
    (u.skills?.[g] ?? []).some((e) => e && typeof e === "object")
  );
  const oldFormat =
    Array.isArray(u.skills) ||
    hasObjects ||
    u.skillLevels !== undefined ||
    u.skillGroups !== undefined ||
    u.skillNames !== undefined;
  if (!oldFormat) continue;
  const { names, levels } = readStoredSkills(u);
  ops.push({
    updateOne: {
      filter: { _id: u._id },
      update: {
        $set: toStoredSkills(names, levels),
        $unset: { skillLevels: "", skillGroups: "", skillNames: "" },
      },
    },
  });
}
if (ops.length) await MobileUser.collection.bulkWrite(ops);
console.log(`Migrated ${ops.length} of ${users.length} user(s) to grouped skills.`);
await mongoose.disconnect();
