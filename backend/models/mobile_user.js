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

    // Profile fields for the mobile app (user-customizable).
    headline: { type: String, default: "" },
    location: { type: String, default: "" },
    phone: { type: String, default: "" },
    portfolioUrl: { type: String, default: "" },
    bio: { type: String, default: "" },
    avatarUrl: { type: String, default: "" },
    skills: { type: [String], default: [] },
    education: { type: [educationItemSchema], default: [] },
    experience: { type: [experienceItemSchema], default: [] },

    // Flexible bucket for extra user-defined fields.
    profile: { type: mongoose.Schema.Types.Mixed, default: {} },
}, { timestamps: true, collection: "mobile_users" });

const MobileUser = mongoose.model("MobileUser", mobileUserSchema);

export default MobileUser;