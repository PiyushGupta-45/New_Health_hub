# FitTrack Backend API

Simple Node.js/Express backend for FitTrack app with MongoDB Atlas.

## Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Create .env File

Create a `.env` file in the `backend` folder:

```env
MONGODB_URI=mongodb+srv://admin:admin@cluster0.dsnzo0s.mongodb.net/?appName=Cluster0
JWT_SECRET=your-secret-key-here
PORT=3000
```

### 3. Run the Server

```bash
node server.js
```

Or for development with auto-reload:

```bash
npm run dev
```

The server will run on `http://localhost:3000`

## API Endpoints

- `POST /api/auth/signup` - Sign up with email/password
- `POST /api/auth/signin` - Sign in with email/password
- `POST /api/auth/google` - Sign in with Google
- `GET /api/health` - Health check

## Deploy

See `../DEPLOY_BACKEND.md` for deployment instructions to Render, Railway, or Heroku.

