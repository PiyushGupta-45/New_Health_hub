# Test Your Backend API

Your backend is deployed at: `https://new-health-hub.onrender.com`

## Step 1: Test Health Endpoint

Open in your browser:
```
https://new-health-hub.onrender.com/api/health
```

**Expected Response:**
```json
{"status":"OK","message":"Server is running"}
```

If this works, your backend is running! ✅

## Step 2: Test Google Auth Endpoint

The endpoint exists in the code at: `POST /api/auth/google`

You can test it with curl:
```bash
curl -X POST https://new-health-hub.onrender.com/api/auth/google \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","name":"Test User","idToken":"test-token"}'
```

## Step 3: Update Your .env File

Make sure your `.env` file has:
```env
API_BASE_URL=https://new-health-hub.onrender.com
```

**Important:**
- No trailing slash
- No quotes
- Must be exactly: `https://new-health-hub.onrender.com`

## Step 4: Check Backend Logs on Render

1. Go to https://dashboard.render.com
2. Click on your service `new-health-hub`
3. Check the "Logs" tab
4. Look for:
   - "Connected to MongoDB Atlas" ✅
   - "Server running on port..." ✅
   - Any error messages ❌

## Common Issues

### Issue: 404 Not Found
**Possible causes:**
1. Backend not fully deployed yet (wait a few minutes)
2. Wrong endpoint path
3. Backend crashed

**Fix:**
- Check Render logs
- Verify deployment status is "Live"
- Restart the service if needed

### Issue: MongoDB Connection Error
**Fix:**
- Check `MONGODB_URI` environment variable in Render
- Verify MongoDB Atlas allows connections from Render's IP
- Check MongoDB Atlas network access settings

### Issue: CORS Error
**Fix:**
- The backend already has `app.use(cors())` which should work
- If still having issues, check Render logs

## Verify All Endpoints

Your backend should have these endpoints:

1. ✅ `GET /api/health` - Health check
2. ✅ `POST /api/auth/signup` - Sign up
3. ✅ `POST /api/auth/signin` - Sign in  
4. ✅ `POST /api/auth/google` - Google sign in

All endpoints are in the `backend/server.js` file I created.

