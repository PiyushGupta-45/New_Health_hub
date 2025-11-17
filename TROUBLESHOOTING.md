# Troubleshooting: "Not Found" Error

## The Problem

You're seeing: **"Backend API not found"** or **"Not Found"** error.

This means your Flutter app can't reach your backend API server.

## Quick Checks

### 1. Check Your .env File

Open your `.env` file and verify:

```env
API_BASE_URL=https://your-backend-url.com
```

**Common Mistakes:**
- ❌ Using MongoDB connection string: `mongodb+srv://...`
- ❌ Missing `http://` or `https://`
- ❌ Wrong URL format

**Correct Format:**
- ✅ `https://your-app.onrender.com`
- ✅ `https://your-app.railway.app`
- ✅ `http://localhost:3000` (for local testing only)

### 2. Test Your Backend URL

Open your browser and visit:

```
https://your-backend-url.com/api/health
```

**Expected Response:**
```json
{"status":"OK","message":"Server is running"}
```

**If you get:**
- ❌ "This site can't be reached" → Backend not deployed
- ❌ "404 Not Found" → Wrong URL or endpoint doesn't exist
- ❌ "500 Internal Server Error" → Backend has an error

### 3. Verify Backend is Deployed

**For Render:**
- Go to https://dashboard.render.com
- Check if your service shows "Live" status
- Check logs for any errors

**For Railway:**
- Go to https://railway.app
- Check deployment status
- View logs

**For Heroku:**
- Go to https://dashboard.heroku.com
- Check if app is running
- View logs: `heroku logs --tail`

### 4. Check Backend Endpoints

Your backend should have these endpoints:
- ✅ `POST /api/auth/signup`
- ✅ `POST /api/auth/signin`
- ✅ `POST /api/auth/google`
- ✅ `GET /api/health` (for testing)

### 5. Test Backend Manually

Use a tool like Postman or curl to test:

```bash
# Test health endpoint
curl https://your-backend-url.com/api/health

# Test signup
curl -X POST https://your-backend-url.com/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"test@test.com","password":"123456"}'
```

## Solutions

### Solution 1: Deploy Your Backend

If you haven't deployed yet, follow `QUICK_START.md`:

1. Push backend code to GitHub
2. Deploy to Render (easiest)
3. Get your backend URL
4. Update `.env` file

### Solution 2: Fix API_BASE_URL

If your backend is deployed:

1. **Get the correct URL:**
   - Render: `https://your-app.onrender.com`
   - Railway: `https://your-app.railway.app`
   - Heroku: `https://your-app.herokuapp.com`

2. **Update `.env` file:**
   ```env
   API_BASE_URL=https://your-actual-backend-url.com
   ```

3. **Restart your Flutter app:**
   ```bash
   flutter clean
   flutter pub get
   flutter run
   ```

### Solution 3: Test Locally First

If you want to test before deploying:

1. **Start backend locally:**
   ```bash
   cd backend
   npm install
   node server.js
   ```

2. **Update `.env` for Android Emulator:**
   ```env
   API_BASE_URL=http://10.0.2.2:3000
   ```

3. **Update `.env` for iOS Simulator:**
   ```env
   API_BASE_URL=http://localhost:3000
   ```

### Solution 4: Check CORS (If Testing Locally)

If testing locally, make sure CORS is enabled in your backend. The backend code I provided already includes CORS, but verify:

```javascript
const cors = require('cors');
app.use(cors());
```

## Common Issues

### Issue: "This site can't be reached"
**Cause:** Backend not deployed or wrong URL  
**Fix:** Deploy backend or fix URL in `.env`

### Issue: "404 Not Found"
**Cause:** Endpoint doesn't exist or wrong path  
**Fix:** Check backend code has `/api/auth/google` endpoint

### Issue: "500 Internal Server Error"
**Cause:** Backend code has an error  
**Fix:** Check backend logs and fix the error

### Issue: "Network error"
**Cause:** Can't connect to backend  
**Fix:** Check internet connection and backend URL

## Still Having Issues?

1. **Check backend logs** for errors
2. **Verify MongoDB connection** in backend
3. **Test endpoints** with Postman/curl
4. **Check `.env` file** is in the correct location (project root)
5. **Restart Flutter app** after changing `.env`

## Quick Test

Run this in your browser to test your backend:

```
https://your-backend-url.com/api/health
```

If this works, your backend is running. If not, you need to deploy it first.

