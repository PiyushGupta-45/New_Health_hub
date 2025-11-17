# Debug Backend Connection Issues

## Step 1: Check Console Logs

When you try to sign in, check your Flutter console/logs. You should see:

```
✅ Using API_BASE_URL: https://your-backend-url.com
🌐 Making request to: https://your-backend-url.com/api/auth/google
📡 Response status: 404
📡 Response body: Not Found
```

This will tell you:
- What URL the app is using
- What endpoint it's trying to reach
- What response it's getting

## Step 2: Verify .env File

1. **Check .env file exists** in your project root (same level as `pubspec.yaml`)
2. **Check the format**:
   ```env
   API_BASE_URL=https://your-backend-url.com
   ```
   - No quotes around the URL
   - No trailing slash
   - Must start with `http://` or `https://`

3. **Common mistakes**:
   - ❌ `API_BASE_URL="https://..."` (quotes not needed)
   - ❌ `API_BASE_URL=https://.../` (trailing slash)
   - ❌ `API_BASE_URL=your-backend-url.com` (missing http://)

## Step 3: Test Backend in Browser

Open your browser and test these URLs:

1. **Health check**:
   ```
   https://your-backend-url.com/api/health
   ```
   Should return: `{"status":"OK","message":"Server is running"}`

2. **If health check works but auth doesn't**, check:
   - Backend has `/api/auth/google` endpoint
   - Backend is handling POST requests
   - CORS is enabled

## Step 4: Common Issues & Fixes

### Issue: "API_BASE_URL is not set"
**Fix**: 
- Make sure `.env` file is in project root
- Restart Flutter app after creating/editing `.env`
- Run `flutter clean && flutter pub get`

### Issue: "404 Not Found"
**Possible causes**:
1. **Wrong URL** - Check your `.env` file
2. **Backend not deployed** - Deploy your backend first
3. **Wrong endpoint path** - Backend might use different path

**Fix**:
- Verify backend URL in browser: `https://your-url.com/api/health`
- Check backend code has `/api/auth/google` endpoint
- Check backend logs for errors

### Issue: "Network error" or "Connection refused"
**Fix**:
- Check backend is actually running
- Check internet connection
- For local testing, use correct URL:
  - Android emulator: `http://10.0.2.2:3000`
  - iOS simulator: `http://localhost:3000`

### Issue: Backend works in browser but not in app
**Possible causes**:
1. **CORS issue** - Backend needs to allow Flutter app origin
2. **HTTPS vs HTTP** - Some platforms require HTTPS
3. **Network security** - Android blocks cleartext HTTP by default

**Fix**:
- Check backend has CORS enabled: `app.use(cors())`
- Use HTTPS if possible
- For Android HTTP, add to `AndroidManifest.xml`:
  ```xml
  <application android:usesCleartextTraffic="true">
  ```

## Step 5: Verify Backend Endpoints

Your backend should have these routes:

```javascript
app.post('/api/auth/signup', ...)
app.post('/api/auth/signin', ...)
app.post('/api/auth/google', ...)
app.get('/api/health', ...)
```

Test each in browser or Postman:
```bash
# Test health
curl https://your-backend-url.com/api/health

# Test signup
curl -X POST https://your-backend-url.com/api/auth/signup \
  -H "Content-Type: application/json" \
  -d '{"name":"Test","email":"test@test.com","password":"123456"}'
```

## Step 6: Check Backend Logs

Check your backend server logs for:
- Connection errors
- MongoDB connection issues
- Route not found errors
- CORS errors

## Quick Checklist

- [ ] `.env` file exists in project root
- [ ] `API_BASE_URL` is correct (no trailing slash, has http:// or https://)
- [ ] Backend is deployed and running
- [ ] `https://your-backend-url.com/api/health` works in browser
- [ ] Backend has `/api/auth/google` endpoint
- [ ] CORS is enabled in backend
- [ ] Flutter app restarted after changing `.env`
- [ ] Check console logs for debug messages

## Still Not Working?

1. **Share the console logs** - Look for the debug messages I added
2. **Test backend manually** - Use Postman or curl
3. **Check backend deployment** - Verify it's actually live
4. **Verify MongoDB connection** - Backend might be failing to connect to MongoDB

The debug messages will tell you exactly what's happening!

