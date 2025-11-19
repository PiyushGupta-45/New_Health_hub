// Simple Node.js/Express backend for FitTrack app
// Install dependencies: npm install express mongoose bcryptjs jsonwebtoken cors dotenv

const express = require('express');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const cors = require('cors');
require('dotenv').config();

const ObjectId = mongoose.Types.ObjectId;

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
  userName: { type: String },
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

// Workout Logs Schema
const workoutLogSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  workoutType: { type: String, required: true },
  startTime: { type: Date, required: true },
  durationSeconds: { type: Number, required: true },
  calories: { type: Number, required: true },
  met: { type: Number },
}, {
  timestamps: true,
});

workoutLogSchema.index({ userId: 1, startTime: -1 });

const WorkoutLog = mongoose.model('WorkoutLog', workoutLogSchema);

// Community Schema
const communityMemberSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  userName: { type: String },
  joinedAt: { type: Date, default: Date.now }
}, { _id: false });

const communitySchema = new mongoose.Schema({
  name: { type: String, required: true },
  isPublic: { type: Boolean, default: true },
  ownerId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  ownerName: { type: String },
  joinCode: { type: String, unique: true, sparse: true },
  members: { type: [communityMemberSchema], default: [] }
}, {
  timestamps: true
});

const Community = mongoose.model('Community', communitySchema);

// Community message schema
const communityMessageSchema = new mongoose.Schema({
  communityId: { type: mongoose.Schema.Types.ObjectId, ref: 'Community', required: true },
  userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
  userName: { type: String },
  message: { type: String, required: true }
}, {
  timestamps: true
});

const CommunityMessage = mongoose.model('CommunityMessage', communityMessageSchema);

const generateJoinCode = async () => {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code;
  let exists = true;
  while (exists) {
    code = '';
    for (let i = 0; i < 6; i += 1) {
      code += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    exists = await Community.exists({ joinCode: code });
  }
  return code;
};

const formatCommunityForUser = (communityDoc, userId) => {
  if (!communityDoc) return null;
  const community = communityDoc.toObject ? communityDoc.toObject() : communityDoc;
  const isOwner = community.ownerId?.toString() === userId.toString();
  const members = community.members || [];
  const memberCount = members.length;
  const joinCode = !community.isPublic && isOwner ? community.joinCode : null;

  return {
    _id: community._id?.toString(),
    name: community.name,
    isPublic: community.isPublic,
    ownerId: community.ownerId?.toString(),
    ownerName: community.ownerName,
    memberCount,
    isOwner,
    joinCode,
    members: members.map(member => ({
      userId: member.userId?.toString(),
      userName: member.userName,
      joinedAt: member.joinedAt
    })),
    createdAt: community.createdAt,
    updatedAt: community.updatedAt
  };
};

const formatCommunityMessage = (messageDoc) => {
  if (!messageDoc) return null;
  const message = messageDoc.toObject ? messageDoc.toObject() : messageDoc;
  return {
    _id: message._id?.toString(),
    communityId: message.communityId?.toString(),
    userId: message.userId?.toString(),
    userName: message.userName,
    message: message.message,
    createdAt: message.createdAt,
    updatedAt: message.updatedAt
  };
};

const formatWorkoutLog = (logDoc) => {
  if (!logDoc) return null;
  const log = logDoc.toObject ? logDoc.toObject() : logDoc;
  return {
    _id: log._id?.toString(),
    workoutType: log.workoutType,
    startTime: log.startTime,
    durationSeconds: log.durationSeconds,
    calories: log.calories,
    met: log.met,
    createdAt: log.createdAt,
    updatedAt: log.updatedAt,
  };
};

const getUserProfile = async (userId) => {
  const user = await User.findById(userId).lean();
  if (!user) {
    return {
      name: 'User',
      email: '',
    };
  }
  return {
    name: user.name ?? user.email ?? 'User',
    email: user.email ?? '',
  };
};

// JWT Secret (use environment variable in production)
const JWT_SECRET = process.env.JWT_SECRET || 'your-secret-key-change-this-in-production';

// Helper function to generate JWT token
const generateToken = (userId) => {
  return jwt.sign({ userId }, JWT_SECRET, { expiresIn: '7d' });
};

// Helper function to get start of today in IST (UTC+5:30)
// Returns a UTC Date object representing midnight IST converted to UTC
const getStartOfTodayIST = () => {
  const now = new Date();
  // Get current UTC time in milliseconds
  const utcNow = now.getTime();
  // IST is UTC+5:30, so add 5.5 hours to UTC to get IST
  const istOffsetMs = 5.5 * 60 * 60 * 1000; // 5 hours 30 minutes in milliseconds
  const istNowMs = utcNow + istOffsetMs;
  const istNow = new Date(istNowMs);
  
  // Get start of day in IST (midnight IST = 00:00:00 IST)
  // Create a new date with the same year, month, day but at midnight
  const istYear = istNow.getUTCFullYear();
  const istMonth = istNow.getUTCMonth();
  const istDay = istNow.getUTCDate();
  
  // Create date at midnight IST (00:00:00 IST)
  const istMidnight = new Date(Date.UTC(istYear, istMonth, istDay, 0, 0, 0, 0));
  
  // Convert IST midnight back to UTC for database storage
  // Subtract the IST offset to get the UTC equivalent
  const utcStartOfDay = new Date(istMidnight.getTime() - istOffsetMs);
  return utcStartOfDay;
};

// Helper function to get end of today in IST
const getEndOfTodayIST = () => {
  const startOfDay = getStartOfTodayIST();
  const istOffsetMs = 5.5 * 60 * 60 * 1000;
  // Add IST offset to get IST time, set to end of day, then convert back to UTC
  const istStartMs = startOfDay.getTime() + istOffsetMs;
  const istStart = new Date(istStartMs);
  const istYear = istStart.getUTCFullYear();
  const istMonth = istStart.getUTCMonth();
  const istDay = istStart.getUTCDate();
  const istEndOfDay = new Date(Date.UTC(istYear, istMonth, istDay, 23, 59, 59, 999));
  const utcEndOfDay = new Date(istEndOfDay.getTime() - istOffsetMs);
  return utcEndOfDay;
};

// Helper function to normalize a date to IST start of day
const normalizeToISTStartOfDay = (date) => {
  if (!date) {
    return getStartOfTodayIST();
  }
  const inputDate = new Date(date);
  const istOffsetMs = 5.5 * 60 * 60 * 1000;
  
  // Convert input date to IST
  const istTimeMs = inputDate.getTime() + istOffsetMs;
  const istTime = new Date(istTimeMs);
  
  // Get start of day in IST
  const istYear = istTime.getUTCFullYear();
  const istMonth = istTime.getUTCMonth();
  const istDay = istTime.getUTCDate();
  const istMidnight = new Date(Date.UTC(istYear, istMonth, istDay, 0, 0, 0, 0));
  
  // Convert back to UTC for database storage
  const utcDateForDB = new Date(istMidnight.getTime() - istOffsetMs);
  return utcDateForDB;
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

    // Get user profile to include userName
    const userProfile = await getUserProfile(userId);

    // Use provided date or today's date (start of day in IST)
    const targetDate = normalizeToISTStartOfDay(date);
    
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
      dailySteps.userName = userProfile.name; // Update userName if changed
      dailySteps.syncedAt = new Date();
      await dailySteps.save();
    } else {
      // Create new entry
      dailySteps = new DailySteps({
        userId,
        userName: userProfile.name,
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
    // Use IST timezone to determine "today"
    const today = getStartOfTodayIST();
    const endOfToday = getEndOfTodayIST();
    const tomorrow = new Date(endOfToday.getTime() + 1); // Add 1ms to make it exclusive

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

// Workout log endpoints
app.post('/api/workouts/logs', verifyToken, async (req, res) => {
  try {
    const { workoutType, startTime, durationSeconds, calories, met } = req.body;

    // Log received data for debugging
    console.log('Received workout log data:', {
      workoutType,
      startTime,
      durationSeconds,
      calories,
      met,
      userId: req.userId,
    });

    if (!workoutType || !startTime || durationSeconds === undefined || calories === undefined) {
      return res.status(400).json({
        success: false,
        message: `Missing required fields. workoutType: ${!!workoutType}, startTime: ${!!startTime}, durationSeconds: ${durationSeconds !== undefined}, calories: ${calories !== undefined}`,
      });
    }

    const parsedDuration = Number(durationSeconds);
    const parsedCalories = Number(calories);
    const parsedMet = met !== undefined ? Number(met) : undefined;
    const parsedStart = new Date(startTime);
    
    console.log('Parsed values:', {
      duration: parsedDuration,
      calories: parsedCalories,
      met: parsedMet,
      startTime: parsedStart,
      isValidStart: !Number.isNaN(parsedStart.getTime()),
    });

    if (!Number.isFinite(parsedDuration) || parsedDuration <= 0) {
      return res.status(400).json({
        success: false,
        message: 'Duration must be a positive number of seconds',
      });
    }

    if (!Number.isFinite(parsedCalories) || parsedCalories < 0) {
      return res.status(400).json({
        success: false,
        message: `Calories must be a non-negative number. Received: ${calories}`,
      });
    }

    if (Number.isNaN(parsedStart.getTime())) {
      return res.status(400).json({
        success: false,
        message: 'Invalid start time provided',
      });
    }

    const log = await WorkoutLog.create({
      userId: req.userId,
      workoutType: workoutType.toString().trim(),
      startTime: parsedStart,
      durationSeconds: Math.round(parsedDuration),
      calories: parsedCalories,
      met: parsedMet,
    });

    return res.status(201).json({
      success: true,
      data: formatWorkoutLog(log),
    });
  } catch (error) {
    console.error('Create workout log error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error while saving workout',
    });
  }
});

app.get('/api/workouts/logs', verifyToken, async (req, res) => {
  try {
    const { limit = 50 } = req.query;
    const parsedLimit = Math.min(Math.max(parseInt(limit, 10) || 50, 1), 200);

    const logs = await WorkoutLog.find({ userId: req.userId })
      .sort({ startTime: -1 })
      .limit(parsedLimit)
      .lean();

    return res.json({
      success: true,
      data: logs.map(formatWorkoutLog),
    });
  } catch (error) {
    console.error('Fetch workout logs error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error while fetching workouts',
    });
  }
});

// --- Community Endpoints ---

// Create community
app.post('/api/community/create', verifyToken, async (req, res) => {
  try {
    const { name, isPublic = true } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Community name is required'
      });
    }

    const ownerProfile = await getUserProfile(req.userId);
    const joinCode = isPublic ? null : await generateJoinCode();

    const community = await Community.create({
      name: name.trim(),
      isPublic,
      ownerId: req.userId,
      ownerName: ownerProfile.name,
      joinCode,
      members: [
        {
          userId: req.userId,
          userName: ownerProfile.name
        }
      ]
    });

    return res.status(201).json({
      success: true,
      data: formatCommunityForUser(community, req.userId)
    });
  } catch (error) {
    console.error('Create community error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error while creating community'
    });
  }
});

// List public communities
app.get('/api/community/list', verifyToken, async (req, res) => {
  try {
    const communities = await Community.find({ isPublic: true })
      .sort({ createdAt: -1 })
      .lean();

    return res.json({
      success: true,
      data: communities.map((community) => formatCommunityForUser(community, req.userId))
    });
  } catch (error) {
    console.error('List communities error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error while fetching communities'
    });
  }
});

// Get user's communities
app.get('/api/community/my-communities', verifyToken, async (req, res) => {
  try {
    const communities = await Community.find({
      $or: [
        { ownerId: req.userId },
        { 'members.userId': req.userId }
      ]
    })
      .sort({ updatedAt: -1 })
      .lean();

    return res.json({
      success: true,
      data: communities.map((community) => formatCommunityForUser(community, req.userId))
    });
  } catch (error) {
    console.error('My communities error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error while fetching your communities'
    });
  }
});

// Join public community
app.post('/api/community/:communityId/join', verifyToken, async (req, res) => {
  try {
    const { communityId } = req.params;
    const community = await Community.findById(communityId);

    if (!community) {
      return res.status(404).json({
        success: false,
        message: 'Community not found'
      });
    }

    if (!community.isPublic) {
      return res.status(403).json({
        success: false,
        message: 'This community requires a join code'
      });
    }

    const members = community.members || [];
    if (!community.members) {
      community.members = members;
    }
    const alreadyMember = members.some(
      (member) => member.userId.toString() === req.userId.toString()
    );

    if (!alreadyMember) {
      const profile = await getUserProfile(req.userId);
      community.members.push({
        userId: req.userId,
        userName: profile.name
      });
      await community.save();
    }

    return res.json({
      success: true,
      data: formatCommunityForUser(community, req.userId)
    });
  } catch (error) {
    console.error('Join community error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error while joining community'
    });
  }
});

// Join with code
app.post('/api/community/join-with-code', verifyToken, async (req, res) => {
  try {
    const { joinCode } = req.body;
    if (!joinCode || !joinCode.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Join code is required'
      });
    }

    const community = await Community.findOne({
      joinCode: joinCode.trim().toUpperCase()
    });

    if (!community) {
      return res.status(404).json({
        success: false,
        message: 'Invalid join code'
      });
    }

    const members = community.members || [];
    if (!community.members) {
      community.members = members;
    }
    const alreadyMember = members.some(
      (member) => member.userId.toString() === req.userId.toString()
    );

    if (!alreadyMember) {
      const profile = await getUserProfile(req.userId);
      community.members.push({
        userId: req.userId,
        userName: profile.name
      });
      await community.save();
    }

    return res.json({
      success: true,
      data: formatCommunityForUser(community, req.userId)
    });
  } catch (error) {
    console.error('Join with code error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error while joining with code'
    });
  }
});

// Leave Community
app.post('/api/community/leave', verifyToken, async (req, res) => {
  try {
    const { communityId } = req.body;

    if (!communityId) {
      return res.status(400).json({ success: false, message: 'Community ID required' });
    }

    const communityObjectId = new ObjectId(communityId);
    console.log('🔍 Leave request - req.userId:', req.userId);
    console.log('🔍 Leave request - communityId:', communityId);
    
    const community = await Community.findById(communityObjectId);
    
    if (!community) {
      console.log('❌ Community not found with ID:', communityObjectId);
      return res.status(404).json({ success: false, message: 'Community not found' });
    }

    console.log('✅ Community found:', community.name);
    console.log('🔍 Community ownerId:', community.ownerId);
    console.log('🔍 Community members:', community.members);

    // Owner cannot leave
    if (community.ownerId.toString() === req.userId.toString()) {
      console.log('❌ User is owner, cannot leave');
      return res.status(400).json({
        success: false,
        message: 'Owner must transfer ownership or delete community'
      });
    }

    console.log('🔍 Removing user from members...');
    const beforeCount = community.members.length;
    community.members = (community.members || []).filter(
      (m) => {
        const isMember = m.userId.toString() === req.userId.toString();
        console.log(`  Checking member ${m.userId} vs ${req.userId}: ${isMember}`);
        return !isMember;
      }
    );
    const afterCount = community.members.length;
    console.log(`✅ Members before: ${beforeCount}, after: ${afterCount}`);

    await community.save();
    console.log('✅ Community saved successfully');
    res.json({ success: true, message: 'Left community successfully' });

  } catch (error) {
    console.error('❌ Leave community error:', error);
    res.status(500).json({ success: false, message: 'Error leaving community', error: error.message });
  }
});

// Delete community (owner only)
app.delete('/api/community/delete/:communityId', verifyToken, async (req, res) => {
  try {
    const { communityId } = req.params;

    const communityObjectId = new ObjectId(communityId);
    const community = await Community.findById(communityObjectId);
    
    if (!community) return res.status(404).json({ success: false, message: 'Not found' });

    if (community.ownerId.toString() !== req.userId.toString()) {
      return res.status(403).json({ success: false, message: 'Only owner can delete' });
    }

    await Community.deleteOne({ _id: communityObjectId });
    await CommunityMessage.deleteMany({ communityId: communityObjectId });

    res.json({ success: true, message: 'Community deleted successfully' });

  } catch (error) {
    console.error('Delete community error:', error);
    res.status(500).json({ success: false, message: 'Error deleting community', error: error.message });
  }
});

// Transfer ownership
app.post('/api/community/transfer-owner', verifyToken, async (req, res) => {
  try {
    const { communityId, newOwnerId } = req.body;

    const communityObjectId = new ObjectId(communityId);
    const newOwnerObjectId = new ObjectId(newOwnerId);
    const community = await Community.findById(communityObjectId);
    
    if (!community) return res.status(404).json({ success: false, message: 'Not found' });

    if (community.ownerId.toString() !== req.userId.toString()) {
      return res.status(403).json({ success: false, message: 'Only owner can transfer ownership' });
    }

    const memberExists = community.members.some(
      (m) => m.userId.toString() === newOwnerObjectId.toString()
    );

    if (!memberExists) {
      return res.status(400).json({ success: false, message: 'New owner must be a member' });
    }

    const newOwner = community.members.find(
      (m) => m.userId.toString() === newOwnerObjectId.toString()
    );

    community.ownerId = newOwnerObjectId;
    community.ownerName = newOwner.userName;
    await community.save();

    res.json({ success: true, message: 'Ownership transferred successfully' });

  } catch (error) {
    console.error('Transfer ownership error:', error);
    res.status(500).json({ success: false, message: 'Error transferring ownership', error: error.message });
  }
});

// Send a message
app.post('/api/community/messages', verifyToken, async (req, res) => {
  try {
    const { message, communityId } = req.body;
    if (!message || !message.toString().trim()) {
      return res.status(400).json({
        success: false,
        message: 'Message cannot be empty'
      });
    }
    if (!communityId) {
      return res.status(400).json({
        success: false,
        message: 'Community ID is required'
      });
    }

    const community = await Community.findById(communityId).lean();
    if (!community) {
      return res.status(404).json({
        success: false,
        message: 'Community not found'
      });
    }

    const members = community.members || [];
    const isMember = members.some(
      (member) => member.userId.toString() === req.userId.toString()
    );
    if (!isMember) {
      return res.status(403).json({
        success: false,
        message: 'You must join the community to send messages'
      });
    }

    const profile = await getUserProfile(req.userId);
    const newMessage = await CommunityMessage.create({
      communityId,
      userId: req.userId,
      userName: profile.name,
      message: message.toString().trim()
    });

    // Return message data along with community info for notifications
    const messageData = formatCommunityMessage(newMessage);
    
    return res.status(201).json({
      success: true,
      data: messageData,
      community: {
        _id: community._id?.toString(),
        name: community.name,
        members: community.members || []
      }
    });
  } catch (error) {
    console.error('Send message error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error while sending message'
    });
  }
});

// Fetch messages
app.get('/api/community/messages', verifyToken, async (req, res) => {
  try {
    const { communityId, limit = 50, sortOrder: sortOrderQuery } = req.query;
    if (!communityId) {
      return res.status(400).json({
        success: false,
        message: 'Community ID is required'
      });
    }

    const community = await Community.findById(communityId).lean();
    if (!community) {
      return res.status(404).json({
        success: false,
        message: 'Community not found'
      });
    }

    const members = community.members || [];
    const isMember = members.some(
      (member) => member.userId.toString() === req.userId.toString()
    );
    if (!isMember) {
      return res.status(403).json({
        success: false,
        message: 'You must join the community to read messages'
      });
    }

    const parsedLimit = Math.min(Math.max(parseInt(limit, 10) || 50, 1), 200);
    const sortOrder = (sortOrderQuery || 'asc').toString().toLowerCase() === 'desc' ? -1 : 1;

    let messages = await CommunityMessage.find({ communityId })
      .sort({ createdAt: sortOrder })
      .limit(parsedLimit)
      .lean();

    if (sortOrder === -1) {
      messages = messages.reverse();
    }

    return res.json({
      success: true,
      data: messages.map(formatCommunityMessage)
    });
  } catch (error) {
    console.error('Get messages error:', error);
    return res.status(500).json({
      success: false,
      message: 'Server error while fetching messages'
    });
  }
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});

