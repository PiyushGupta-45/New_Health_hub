// Simple Node.js/Express backend for FitTrack app
// Install dependencies: npm install express mongoose bcryptjs jsonwebtoken cors dotenv

const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Connect to MongoDB Atlas
const MONGODB_URI = process.env.MONGODB_URI || 'mongodb+srv://admin:admin@cluster0.dsnzo0s.mongodb.net/?appName=Cluster0';

console.log('Attempting to connect to MongoDB...');
console.log('MongoDB URI:', MONGODB_URI ? 'Set (hidden)' : 'NOT SET');

mongoose.connect(MONGODB_URI)
  .then(() => {
    console.log('✅ Connected to MongoDB Atlas successfully');
    console.log('Database:', mongoose.connection.name);
  })
  .catch(err => {
    console.error('❌ MongoDB connection error:', err.message);
    console.error('Error details:', err);
  });

// Handle connection events
mongoose.connection.on('error', (err) => {
  console.error('MongoDB connection error:', err);
});

mongoose.connection.on('disconnected', () => {
  console.warn('MongoDB disconnected');
});

// User Schema
const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String },
  googleId: { type: String },
  createdAt: { type: Date, default: Date.now }
});

const User = mongoose.model('User', userSchema);

// Daily Steps Schema
const dailyStepsSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  date: { type: Date, required: true },
  steps: { type: Number, required: true, default: 0 },
  source: { type: String, default: 'Phone Sensor' },
  syncedAt: { type: Date, default: Date.now }
}, {
  timestamps: true
});

// Create compound index to ensure one entry per user per day
dailyStepsSchema.index({ userId: 1, date: 1 }, { unique: true });

const DailySteps = mongoose.model('DailySteps', dailyStepsSchema);

// JWT Secret (use environment variable in production)
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-this-in-production';

// Helper function to generate JWT token
const generateToken = (userId) => {
  return jwt.sign({ userId }, JWT_SECRET, { expiresIn: '7d' });
};

// Sign Up Endpoint
app.post('/api/auth/signup', async (req, res) => {
  try {
    const { name, email, password } = req.body;

    // Validate input
    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Name, email, and password are required'
      });
    }

    // Check if user already exists
    const existingUser = await User.findOne({ email });
    if (existingUser) {
      return res.status(409).json({
        success: false,
        message: 'Email already exists'
      });
    }

    // Hash password
    const hashedPassword = await bcrypt.hash(password, 10);

    // Create user
    const user = new User({
      name,
      email,
      password: hashedPassword
    });

    await user.save();

    // Generate token
    const token = generateToken(user._id);

    res.status(201).json({
      success: true,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        token
      }
    });
  } catch (error) {
    console.error('Signup error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during signup'
    });
  }
});

// Sign In Endpoint
app.post('/api/auth/signin', async (req, res) => {
  try {
    const { email, password } = req.body;

    // Validate input
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Email and password are required'
      });
    }

    // Find user
    const user = await User.findOne({ email });
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Invalid credentials'
      });
    }

    // Check password (skip if Google user)
    if (user.password) {
      const isPasswordValid = await bcrypt.compare(password, user.password);
      if (!isPasswordValid) {
        return res.status(401).json({
          success: false,
          message: 'Invalid credentials'
        });
      }
    } else {
      return res.status(401).json({
        success: false,
        message: 'Please sign in with Google'
      });
    }

    // Generate token
    const token = generateToken(user._id);

    res.json({
      success: true,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        token
      }
    });
  } catch (error) {
    console.error('Signin error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error during signin'
    });
  }
});

// Google Sign In Endpoint
app.post('/api/auth/google', async (req, res) => {
  try {
    console.log('Google signin request received:', JSON.stringify(req.body));
    
    const { email, name, idToken } = req.body;

    if (!email) {
      return res.status(400).json({
        success: false,
        message: 'Email is required'
      });
    }

    // Check MongoDB connection
    if (mongoose.connection.readyState !== 1) {
      console.error('MongoDB not connected. State:', mongoose.connection.readyState);
      return res.status(500).json({
        success: false,
        message: 'Database connection error. Please check MongoDB connection.'
      });
    }

    // Find or create user
    let user = await User.findOne({ email });

    if (user) {
      // User exists, update Google ID if needed
      if (!user.googleId && idToken) {
        user.googleId = idToken; // In production, verify the Google token
        await user.save();
      }
    } else {
      // Create new user
      user = new User({
        name: name || 'User',
        email,
        googleId: idToken
      });
      await user.save();
    }

    // Generate token
    const token = generateToken(user._id);

    console.log('Google signin successful for:', email);
    res.json({
      success: true,
      user: {
        id: user._id,
        name: user.name,
        email: user.email,
        token
      }
    });
  } catch (error) {
    console.error('Google signin error:', error);
    console.error('Error stack:', error.stack);
    res.status(500).json({
      success: false,
      message: `Server error during Google signin: ${error.message}`,
      error: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
});

// Health check endpoint
app.get('/api/health', (req, res) => {
  res.json({ status: 'OK', message: 'Server is running' });
});

// Middleware to verify JWT token
const verifyToken = (req, res, next) => {
  try {
    const token = req.headers.authorization?.split(' ')[1] || req.headers['x-auth-token'];
    
    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'No token provided'
      });
    }

    const decoded = jwt.verify(token, JWT_SECRET);
    req.userId = decoded.userId;
    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: 'Invalid or expired token'
    });
  }
};

// Store daily steps endpoint
app.post('/api/steps', verifyToken, async (req, res) => {
  try {
    const { steps, date, source } = req.body;
    const userId = req.userId;

    if (!steps || steps < 0) {
      return res.status(400).json({
        success: false,
        message: 'Valid steps count is required'
      });
    }

    // Use provided date or today's date (start of day)
    let targetDate;
    if (date) {
      targetDate = new Date(date);
    } else {
      targetDate = new Date();
    }
    targetDate.setHours(0, 0, 0, 0);
    
    const startOfDay = new Date(targetDate);
    const endOfDay = new Date(targetDate);
    endOfDay.setHours(23, 59, 59, 999);

    // Find or create daily steps entry
    let dailySteps = await DailySteps.findOne({
      userId,
      date: {
        $gte: startOfDay,
        $lt: endOfDay
      }
    });

    if (dailySteps) {
      // Update existing entry (use higher value to handle multiple syncs)
      dailySteps.steps = Math.max(dailySteps.steps, steps);
      dailySteps.source = source || dailySteps.source;
      dailySteps.syncedAt = new Date();
      await dailySteps.save();
    } else {
      // Create new entry
      dailySteps = new DailySteps({
        userId,
        date: targetDate,
        steps,
        source: source || 'Phone Sensor',
        syncedAt: new Date()
      });
      await dailySteps.save();
    }

    res.json({
      success: true,
      data: {
        id: dailySteps._id,
        date: dailySteps.date,
        steps: dailySteps.steps,
        source: dailySteps.source
      }
    });
  } catch (error) {
    console.error('Store steps error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while storing steps'
    });
  }
});

// Get steps history endpoint
app.get('/api/steps/history', verifyToken, async (req, res) => {
  try {
    const userId = req.userId;
    const { startDate, endDate, limit = 30 } = req.query;

    const query = { userId };

    // Add date range if provided
    if (startDate || endDate) {
      query.date = {};
      if (startDate) {
        query.date.$gte = new Date(startDate);
      }
      if (endDate) {
        query.date.$lte = new Date(endDate);
      }
    }

    const stepsHistory = await DailySteps.find(query)
      .sort({ date: -1 })
      .limit(parseInt(limit))
      .select('date steps source syncedAt')
      .lean();

    // Format dates for response
    const formattedHistory = stepsHistory.map(entry => ({
      id: entry._id,
      date: entry.date,
      steps: entry.steps,
      source: entry.source,
      syncedAt: entry.syncedAt
    }));

    res.json({
      success: true,
      data: formattedHistory,
      count: formattedHistory.length
    });
  } catch (error) {
    console.error('Get steps history error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while fetching steps history'
    });
  }
});

// Get today's steps endpoint
app.get('/api/steps/today', verifyToken, async (req, res) => {
  try {
    const userId = req.userId;
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const tomorrow = new Date(today);
    tomorrow.setDate(tomorrow.getDate() + 1);

    const todaySteps = await DailySteps.findOne({
      userId,
      date: {
        $gte: today,
        $lt: tomorrow
      }
    }).select('date steps source syncedAt').lean();

    if (todaySteps) {
      res.json({
        success: true,
        data: {
          id: todaySteps._id,
          date: todaySteps.date,
          steps: todaySteps.steps,
          source: todaySteps.source,
          syncedAt: todaySteps.syncedAt
        }
      });
    } else {
      res.json({
        success: true,
        data: {
          date: today,
          steps: 0,
          source: null,
          syncedAt: null
        }
      });
    }
  } catch (error) {
    console.error('Get today steps error:', error);
    res.status(500).json({
      success: false,
      message: 'Server error while fetching today\'s steps'
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

