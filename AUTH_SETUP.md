# Authentication Setup Guide

## Step 1: Install Dependencies

Run the following command to install the new dependencies:

```bash
flutter pub get
```

## Step 2: Create .env File

1. Copy `env_template.txt` to `.env` in the root directory of your project
2. Replace the placeholder values with your actual API credentials:

```
API_BASE_URL=https://your-actual-api-url.com
API_KEY=your-actual-api-key
```

## Step 3: Backend Setup

You need to set up a backend API that connects to MongoDB Atlas. The backend should implement the endpoints described in `BACKEND_API_DOCS.md`.

### Quick Backend Example (Node.js/Express)

```javascript
// Example using Express.js and MongoDB
const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');
const jwt = require('jsonwebtoken');

// Connect to MongoDB Atlas
mongoose.connect(process.env.MONGODB_URI);

// User Schema
const userSchema = new mongoose.Schema({
  name: String,
  email: { type: String, unique: true },
  password: String,
  googleId: String,
});

// Sign Up Endpoint
app.post('/api/auth/signup', async (req, res) => {
  const { name, email, password } = req.body;
  const hashedPassword = await bcrypt.hash(password, 10);
  // Create user and return JWT token
});

// Sign In Endpoint
app.post('/api/auth/signin', async (req, res) => {
  const { email, password } = req.body;
  // Verify credentials and return JWT token
});

// Google Sign In Endpoint
app.post('/api/auth/google', async (req, res) => {
  // Verify Google token and create/update user
});
```

## Step 4: Google Sign-In Configuration

### Android Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create a new project or select existing one
3. Enable Google Sign-In API
4. Create OAuth 2.0 credentials
5. Add your package name and SHA-1 certificate fingerprint
6. The `google_sign_in` package will handle the rest automatically

### iOS Setup

1. Add your OAuth client ID to `ios/Runner/Info.plist`:
```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

## Step 5: Test the Authentication

1. Run the app: `flutter run`
2. Tap the login icon (or user initial) in the top right
3. Try signing up with email/password
4. Try signing in with Google
5. After successful authentication, you should see your initial letter in the top right

## Troubleshooting

### Error: "API_BASE_URL is not set"
- Make sure you created the `.env` file in the root directory
- Check that `API_BASE_URL` is set correctly

### Error: "Network error"
- Verify your backend API is running and accessible
- Check that the API URL in `.env` is correct
- Ensure your backend has proper CORS configuration

### Google Sign-In not working
- Verify Google OAuth credentials are set up correctly
- Check that your package name matches in Google Cloud Console
- For Android, ensure SHA-1 fingerprint is added

### Backend connection issues
- Verify MongoDB Atlas connection string is correct
- Check that your backend API endpoints match the expected format
- Review `BACKEND_API_DOCS.md` for endpoint specifications

