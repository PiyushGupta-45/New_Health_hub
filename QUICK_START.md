# Quick Start Guide - Get Your Backend URL in 5 Minutes

## Easiest Method: Deploy to Render (Free)

### Step 1: Create Backend Files (Already Done ✅)

I've created the backend files in the `backend` folder for you.

### Step 2: Create GitHub Repository

1. Go to https://github.com and create a new repository
2. Name it something like `fittrack-backend`
3. Don't initialize with README

### Step 3: Push to GitHub

Open terminal/command prompt in your project root and run:

```bash
# Initialize git (if not already done)
git init

# Add all files
git add .

# Commit
git commit -m "Initial commit with backend"

# Add your GitHub repo (replace with your actual repo URL)
git remote add origin https://github.com/YOUR_USERNAME/fittrack-backend.git

# Push
git branch -M main
git push -u origin main
```

### Step 4: Deploy to Render

1. **Go to Render**: https://render.com
2. **Sign up** (use GitHub login - easiest)
3. **Click "New"** → **"Web Service"**
4. **Connect your GitHub repository**
5. **Select your repository** and the `backend` folder
6. **Configure**:
   - **Name**: `fittrack-backend` (or any name)
   - **Region**: Choose closest to you
   - **Branch**: `main`
   - **Root Directory**: `backend`
   - **Runtime**: `Node`
   - **Build Command**: `npm install`
   - **Start Command**: `node server.js`
7. **Add Environment Variables**:
   - Click "Add Environment Variable"
   - Add these three:
     ```
     MONGODB_URI = mongodb+srv://admin:admin@cluster0.dsnzo0s.mongodb.net/?appName=Cluster0
     JWT_SECRET = your-random-secret-key-12345
     PORT = (leave empty, Render sets this automatically)
     ```
8. **Click "Create Web Service"**
9. **Wait 2-3 minutes** for deployment
10. **Copy your URL** - It will look like: `https://fittrack-backend.onrender.com`

### Step 5: Update Flutter App

1. **Create `.env` file** in your Flutter project root (if not exists)
2. **Add your backend URL**:
   ```env
   API_BASE_URL=https://fittrack-backend.onrender.com
   API_KEY=
   ```
   (Leave API_KEY empty for now, unless your backend requires it)

3. **Test it**:
   - Open browser and go to: `https://your-app.onrender.com/api/health`
   - You should see: `{"status":"OK","message":"Server is running"}`

### Step 6: Run Your Flutter App

```bash
flutter run
```

Now try signing up or signing in - it should work! 🎉

---

## Alternative: Test Locally First

If you want to test locally before deploying:

### 1. Install Node.js
Download from: https://nodejs.org

### 2. Set Up Backend

```bash
cd backend
npm install
```

### 3. Create .env File

In the `backend` folder, create `.env`:
```env
MONGODB_URI=mongodb+srv://admin:admin@cluster0.dsnzo0s.mongodb.net/?appName=Cluster0
JWT_SECRET=test-secret
PORT=3000
```

### 4. Run Server

```bash
node server.js
```

### 5. Update Flutter .env

For **Android Emulator**:
```env
API_BASE_URL=http://10.0.2.2:3000
```

For **iOS Simulator**:
```env
API_BASE_URL=http://localhost:3000
```

For **Physical Device**:
- Find your computer's IP address
- Use: `http://YOUR_IP:3000`

---

## Need Help?

- **Render Issues**: Check `DEPLOY_BACKEND.md` for detailed instructions
- **Backend Code**: See `backend/server.js` and `backend/README.md`
- **API Documentation**: See `BACKEND_API_DOCS.md`

---

## Summary

1. ✅ Backend code is ready in `backend/` folder
2. 📤 Push to GitHub
3. 🚀 Deploy to Render (free)
4. 🔗 Copy the URL
5. 📝 Update Flutter `.env` file
6. 🎉 Done!

Your backend URL will be something like: `https://your-app.onrender.com`

