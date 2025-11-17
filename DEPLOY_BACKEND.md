# How to Deploy Your Backend API

You have several options to deploy your backend. Here are the easiest ones:

## Option 1: Deploy to Render (Recommended - Free & Easy)

### Steps:

1. **Create a Render Account**
   - Go to https://render.com
   - Sign up with GitHub (easiest)

2. **Prepare Your Backend**
   - Create a new folder called `backend` in your project
   - Copy the `server.js` and `package.json` files I created
   - Create a `.env` file with your MongoDB URI

3. **Push to GitHub**
   ```bash
   git init
   git add .
   git commit -m "Add backend"
   git remote add origin https://github.com/yourusername/your-repo.git
   git push -u origin main
   ```

4. **Deploy on Render**
   - Go to Render Dashboard → New → Web Service
   - Connect your GitHub repository
   - Select the `backend` folder
   - Set these:
     - **Build Command**: `npm install`
     - **Start Command**: `node server.js`
     - **Environment Variables**:
       - `MONGODB_URI`: Your MongoDB connection string
       - `JWT_SECRET`: A random secret string
       - `PORT`: 3000 (or leave empty)
   - Click "Create Web Service"
   - Wait 2-3 minutes for deployment
   - Copy your URL (e.g., `https://your-app.onrender.com`)

5. **Update Your Flutter App**
   - In your `.env` file, set:
     ```env
     API_BASE_URL=https://your-app.onrender.com
     ```

---

## Option 2: Deploy to Railway (Free Tier Available)

### Steps:

1. **Sign up at Railway**: https://railway.app

2. **Create New Project** → Deploy from GitHub

3. **Select your repository** and the `backend` folder

4. **Add Environment Variables**:
   - `MONGODB_URI`: Your MongoDB connection string
   - `JWT_SECRET`: Random secret string
   - `PORT`: 3000

5. **Deploy** - Railway auto-detects Node.js and deploys

6. **Get your URL** (e.g., `https://your-app.railway.app`)

7. **Update Flutter `.env`**:
   ```env
   API_BASE_URL=https://your-app.railway.app
   ```

---

## Option 3: Deploy to Heroku (Free Tier Discontinued, but Still Works)

### Steps:

1. **Install Heroku CLI**: https://devcenter.heroku.com/articles/heroku-cli

2. **Login**:
   ```bash
   heroku login
   ```

3. **Create App**:
   ```bash
   cd backend
   heroku create your-app-name
   ```

4. **Set Environment Variables**:
   ```bash
   heroku config:set MONGODB_URI="mongodb+srv://admin:admin@cluster0.dsnzo0s.mongodb.net/?appName=Cluster0"
   heroku config:set JWT_SECRET="your-secret-key"
   ```

5. **Deploy**:
   ```bash
   git push heroku main
   ```

6. **Get URL**: `https://your-app-name.herokuapp.com`

---

## Option 4: Use Firebase (No Backend Code Needed)

If you want to avoid backend setup entirely:

1. **Go to Firebase Console**: https://console.firebase.google.com
2. **Create a new project**
3. **Enable Authentication** → Email/Password and Google
4. **Use Firebase SDK in Flutter** instead of custom backend

This requires changing your Flutter code to use Firebase SDK.

---

## Option 5: Quick Local Testing (For Development Only)

If you just want to test locally:

1. **Install Node.js**: https://nodejs.org

2. **Set up backend**:
   ```bash
   cd backend
   npm install
   ```

3. **Create `.env` file**:
   ```env
   MONGODB_URI=mongodb+srv://admin:admin@cluster0.dsnzo0s.mongodb.net/?appName=Cluster0
   JWT_SECRET=test-secret
   PORT=3000
   ```

4. **Run server**:
   ```bash
   node server.js
   ```

5. **For Android Emulator**, use:
   ```env
   API_BASE_URL=http://10.0.2.2:3000
   ```

6. **For iOS Simulator**, use:
   ```env
   API_BASE_URL=http://localhost:3000
   ```

---

## Recommended: Render (Easiest)

**Render** is the easiest option:
- ✅ Free tier available
- ✅ Automatic deployments from GitHub
- ✅ Easy environment variable setup
- ✅ HTTPS included
- ✅ No credit card required for free tier

### Quick Render Setup:

1. Sign up at render.com
2. New → Web Service
3. Connect GitHub repo
4. Point to `backend` folder
5. Add environment variables
6. Deploy!
7. Copy the URL to your Flutter `.env` file

---

## After Deployment

Once you have your backend URL:

1. **Update `.env` in Flutter app**:
   ```env
   API_BASE_URL=https://your-backend-url.com
   ```

2. **Test the API**:
   - Visit: `https://your-backend-url.com/api/health`
   - Should return: `{"status":"OK","message":"Server is running"}`

3. **Run your Flutter app**:
   ```bash
   flutter run
   ```

Your authentication should now work! 🎉

