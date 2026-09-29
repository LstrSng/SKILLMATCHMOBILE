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
        // Uploaded certificate/proof of employment: { name, url, publicId,
        // resourceType, format, mimeType, size, updatedAt } (or `data`
        // base64 when Cloudinary isn't configured). Null when none.
        proof: { type: mongoose.Schema.Types.Mixed, default: null },
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
    skills: {
        techStack: { type: [String], default: [] },
        functional: { type: [String], default: [] },
        enabling: { type: [String], default: [] },
    },
    education: { type: [educationItemSchema], default: [] },
    experience: { type: [experienceItemSchema], default: [] },

    // Structured background for analytics. Null/"" until the user sets them
    // (accounts created before these fields existed).
    yearsOfExperience: { type: Number, default: null, min: 0, max: 40 },
    highestEducation: { type: String, default: "" },

    // Flexible bucket for extra user-defined fields.
    profile: { type: mongoose.Schema.Types.Mixed, default: {} },
}, { timestamps: true, collection: "mobile_users" });

const MobileUser = mongoose.model("MobileUser", mobileUserSchema);

export default MobileUser;