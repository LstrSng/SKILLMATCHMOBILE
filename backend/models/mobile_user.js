import mongoose from 'mongoose';

const educationItemSchema = new mongoose.Schema(
    {
        degree: { type: String, default: "" },
        school: { type: String, default: "" },
        years: { type: String, default: "" },
    },
    { _id: false }
);

const experienceItemSchema = new mongoose.Schema(
    {
        year: { type: String, default: "" },
        title: { type: String, default: "" },
        company: { type: String, default: "" },
        description: { type: String, default: "" },
    },
    { _id: false }
);

const skillItemSchema = new mongoose.Schema(
    {
        name: { type: String, required: true },
        level: { type: Number, min: 1, max: 10, default: null },
    },
    { _id: false }
);

const mobileUserSchema = new mongoose.Schema({
    firstName: {
        type: String,
        required: true
    },

    lastName: {
        type: String,
        required: true
    },

    email: {
        type: String,
        required: true,
        unique: true
    },

    password: {
        type: String,
        required: true
    },

    // false until the sign-up OTP is entered. Missing on accounts created
    // before this field existed (those were verified at sign-up).
    emailVerified: { type: Boolean },

    // Profile fields for the mobile app (user-customizable).
    headline: { type: String, default: "" },
    location: { type: String, default: "" },
    phone: { type: String, default: "" },
    portfolioUrl: { type: String, default: "" },
    bio: { type: String, default: "" },
    avatarUrl: { type: String, default: "" },
    // Skills sorted like the app's profile screen (PSF-SDS catalogs), each
    // with the applicant's self-rated level, 1 (beginner) to 10 (expert).
    // Build with toStoredSkills() in utils/skill_groups.js.
    skills: {
        techStack: { type: [skillItemSchema], default: [] },
        functional: { type: [skillItemSchema], default: [] },
        enabling: { type: [skillItemSchema], default: [] },
    },
    // Plain list of all skill names, for readers that expect a flat list
    // (e.g. the employer web app). Kept in sync by toStoredSkills().
    skillNames: { type: [String], default: [] },
    education: { type: [educationItemSchema], default: [] },
    experience: { type: [experienceItemSchema], default: [] },

    // Flexible bucket for extra user-defined fields.
    profile: { type: mongoose.Schema.Types.Mixed, default: {} },
}, { timestamps: true, collection: "mobile_users" });

const MobileUser = mongoose.model("MobileUser", mobileUserSchema);

export default MobileUser;