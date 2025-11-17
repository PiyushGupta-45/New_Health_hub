# Fix 500 Server Error

## The Problem

You're getting a **500 Internal Server Error** when trying to sign in with Google. This means:
- ✅ Backend is deployed and running
- ✅ Endpoint exists and is being reached
- ❌ Something is failing on the server side

## Most Common Causes

### 1. MongoDB Connection Issue (Most Likely)

The backend can't connect to MongoDB Atlas.

**Check Render Logs:**
1. Go to https://dashboard.render.com
2. Click on your `new-health-hub` service
3. Go to "Logs" tab
4. Look for:
   - ❌ "MongoDB connection error"
   - ❌ "MongoDB not connected"
   - ✅ "Connected to MongoDB Atlas successfully"

**Fix:**
1. **Check Environment Variables in Render:**
   - Go to your service → Environment
   - Verify `MONGODB_URI` is set correctly
   - Should be: `mongodb+srv://admin:admin@cluster0.dsnzo0s.mongodb.net/?appName=Cluster0`

2. **Check MongoDB Atlas Network Access:**
   - Go to MongoDB Atlas → Network Access
   - Make sure you allow connections from anywhere: `0.0.0.0/0`
   - Or add Render's IP addresses

3. **Check MongoDB Atlas Database User:**
   - Verify the username/password are correct
   - Make sure the user has read/write permissions

### 2. Missing Environment Variables

**Check Render Environment Variables:**
- `MONGODB_URI` - Your MongoDB connection string
- `JWT_SECRET` - Secret key for tokens (optional, has default)
- `PORT` - Server port (optional, defaults to 3000)

### 3. Database/Collection Issues

The User model might be failing to save.

**Check:**
- MongoDB database exists
- Collection can be created
- User has proper permissions

## How to Debug

### Step 1: Check Render Logs

The updated backend code now logs more details:
- Connection attempts
- Request data
- Error messages with stack traces

Look for lines like:
```
Google signin error: [error message]
Error stack: [stack trace]
```

### Step 2: Test MongoDB Connection

In Render logs, you should see:
```
✅ Connected to MongoDB Atlas successfully
```

If you see:
```
❌ MongoDB connection error: [error]
```

Then MongoDB is the problem.

### Step 3: Test the Endpoint Manually

Use curl or Postman to test:
```bash
curl -X POST https://new-health-hub.onrender.com/api/auth/google \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "name": "Test User",
    "idToken": "test-token"
  }'
```

Check what error you get.

## Quick Fixes

### Fix 1: Update MongoDB URI in Render

1. Go to Render Dashboard → Your Service → Environment
2. Add/Update `MONGODB_URI`:
   ```
   mongodb+srv://admin:admin@cluster0.dsnzo0s.mongodb.net/?appName=Cluster0
   ```
3. Save and redeploy

### Fix 2: Check MongoDB Atlas

1. Go to MongoDB Atlas
2. **Network Access** → Add IP Address → `0.0.0.0/0` (allow all)
3. **Database Access** → Verify user `admin` exists and has permissions

### Fix 3: Redeploy Backend

After updating environment variables:
1. Go to Render Dashboard
2. Click "Manual Deploy" → "Deploy latest commit"
3. Wait for deployment to complete
4. Check logs again

## Updated Backend Code

I've updated the backend code to:
- ✅ Log more details about errors
- ✅ Check MongoDB connection before processing
- ✅ Show actual error messages (not just generic "server error")
- ✅ Log request data for debugging

**Next Steps:**
1. Update your `backend/server.js` with the new code
2. Push to GitHub
3. Render will auto-deploy
4. Check logs for detailed error messages

## Still Not Working?

Share the Render logs - they should now show the actual error message instead of just "Server error during Google signin".

