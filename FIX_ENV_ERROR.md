# Fix: MongoDB Connection String Error

## The Problem

You're seeing this error:
```
Google sign in error: Invalid argument(s): Unsupported scheme 'mongodb+srv' in URI mongodb+srv://...
```

This happens because you've put your **MongoDB Atlas connection string** in the `API_BASE_URL` field in your `.env` file.

## The Solution

The `API_BASE_URL` should be the URL of your **backend API server**, NOT your MongoDB connection string.

### What You Need:

1. **MongoDB Connection String** → Used by your **backend server** to connect to MongoDB Atlas
2. **Backend API URL** → Used by your **Flutter app** to make HTTP requests

### Example:

❌ **WRONG** (What you have now):
```env
API_BASE_URL=mongodb+srv://admin:admin@cluster0.dsnzo0s.mongodb.net/?appName=Cluster0
```

✅ **CORRECT** (What you need):
```env
API_BASE_URL=https://your-backend-api.herokuapp.com
# OR
API_BASE_URL=https://api.yourdomain.com
# OR if running locally:
API_BASE_URL=http://localhost:3000
```

## Steps to Fix:

### Step 1: Set Up a Backend API Server

You need to create a backend server (Node.js, Python, etc.) that:
- Connects to MongoDB Atlas using your MongoDB connection string
- Provides REST API endpoints for authentication
- Handles `/api/auth/signup`, `/api/auth/signin`, and `/api/auth/google`

See `BACKEND_API_DOCS.md` for the API endpoint specifications.

### Step 2: Update Your .env File

Once your backend is deployed, update your `.env` file:

```env
# Your backend API URL (NOT MongoDB connection string)
API_BASE_URL=https://your-backend-url.com

# Optional: Your API key if your backend requires it
API_KEY=your-api-key-here
```

### Step 3: Keep MongoDB Connection String in Backend

Your MongoDB connection string should **only** be used in your backend server code, not in the Flutter app.

Example backend code (Node.js):
```javascript
// Backend only - NOT in Flutter app
const mongoose = require('mongoose');
mongoose.connect('mongodb+srv://admin:admin@cluster0.dsnzo0s.mongodb.net/?appName=Cluster0');
```

## Quick Test Backend Options:

### Option 1: Use a Backend-as-a-Service
- **Firebase** (with Firestore)
- **Supabase**
- **Backendless**
- **Appwrite**

### Option 2: Deploy Your Own Backend
- **Heroku** (free tier available)
- **Railway**
- **Render**
- **Vercel** (for serverless functions)
- **AWS/Google Cloud/Azure**

### Option 3: Run Locally for Testing
If testing on an emulator, you can use:
```env
API_BASE_URL=http://10.0.2.2:3000  # Android emulator
# OR
API_BASE_URL=http://localhost:3000  # iOS simulator
```

## Summary

- ✅ `API_BASE_URL` = Your backend API server URL (http:// or https://)
- ❌ `API_BASE_URL` ≠ MongoDB connection string (mongodb:// or mongodb+srv://)
- 🔒 MongoDB connection string stays in your backend server only

After fixing your `.env` file, the error should be resolved!

