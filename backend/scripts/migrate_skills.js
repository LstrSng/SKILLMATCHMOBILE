// One-time migration of mobile users to the grouped skills format:
//   skills: [String] + skillLevels: { name: level }
//     -> skills: { techStack, functional, enabling: [{ name, level }] }
//        + skillNames: [String]
// and removes the old skillLevels / skillGroups fields. Users already in
// the new format are left as they are. Safe to run again.
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
  .find({}, { projection: { skills: 1, skillLevels: 1, skillGroups: 1 } })
  .toArray();

const ops = [];
for (const u of users) {
  const oldFormat =
    Array.isArray(u.skills) || u.skillLevels !== undefined || u.skillGroups !== undefined;
  if (!oldFormat) continue;
  const { names, levels } = readStoredSkills(u);
  ops.push({
    updateOne: {
      filter: { _id: u._id },
      update: {
        $set: toStoredSkills(names, levels),
        $unset: { skillLevels: "", skillGroups: "" },
      },
    },
  });
}
if (ops.length) await MobileUser.collection.bulkWrite(ops);
console.log(`Migrated ${ops.length} of ${users.length} user(s) to grouped skills.`);
await mongoose.disconnect();
