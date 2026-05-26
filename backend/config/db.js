import mongoose from 'mongoose';
const MONGODB_URI = process.env.MONGODB_URI;

export default function connectDB() {
  if (!MONGODB_URI) {
    console.warn('[DB] MONGODB_URI not set — skipping DB connection (test mode)');
    return;
  }
  try {
    mongoose.connect(MONGODB_URI);
    // ... rest of your code
  } catch (err) {
    console.error(err.message);
    process.exit(1);
  }
}
