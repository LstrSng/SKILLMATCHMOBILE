import mongoose from 'mongoose';

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
}, { timestamps: true, collection: "mobile_users" });

const MobileUser = mongoose.model("MobileUser", mobileUserSchema);

export default MobileUser;