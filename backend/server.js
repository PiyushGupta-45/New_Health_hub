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
const ObjectId = mongoose.Types.ObjectId;
const JWT_SECRET = process.env.JWT_SECRET || 'your_jwt_secret_here';

// Verify token middleware (ensures req.userId is set)
const verifyToken = (req, res, next) => {
  const authHeader = req.headers['authorization'] || req.headers['Authorization'];
  const token = authHeader && authHeader.split(' ')[1];
  if (!token) return res.status(401).json({ message: 'No token provided' });

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    req.userId = decoded.userId; // keep as string; convert when querying
    req.userName = decoded.name || decoded.userName || '';
    next();
  } catch (err) {
    console.error('Token verify failed:', err.message);
    return res.status(401).json({ message: 'Invalid or expired token' });
  }
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

// --- Community Endpoints ---

// Create community endpoint (ensure ownerId stored as ObjectId)
app.post('/api/community/create', verifyToken, async (req, res) => {
  try {
    const { name, isPublic } = req.body;
    const ownerObjectId = ObjectId(req.userId);

    const community = new Community({
      name,
      isPublic: !!isPublic,
      ownerId: ownerObjectId,
      ownerName: req.userName || '',
      joinCode: await generateJoinCode(),
      members: [{ userId: ownerObjectId, userName: req.userName || '' }]
    });

    const saved = await community.save();
    res.json({ success: true, community: formatCommunityForUser(saved, req.userId) });
  } catch (err) {
    console.error('Create community error:', err);
    res.status(500).json({ success: false, message: 'Failed to create community' });
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

// Get user's communities (convert req.userId to ObjectId before querying)
app.get('/api/community/my-communities', verifyToken, async (req, res) => {
  try {
    const userObjectId = ObjectId(req.userId);

    const communities = await Community.find({
      $or: [
        { ownerId: userObjectId },
        { 'members.userId': userObjectId }
      ]
    }).sort({ createdAt: -1 });

    res.json({
      success: true,
      communities: communities.map(c => formatCommunityForUser(c, req.userId))
    });
  } catch (error) {
    console.error('Error fetching communities:', error);
    res.status(500).json({ message: 'Failed to fetch communities', error: error.message });
  }
});

// Join community (ensure members.userId saved as ObjectId)
app.post('/api/community/:id/join', verifyToken, async (req, res) => {
  try {
    const communityId = req.params.id;
    const userObjectId = ObjectId(req.userId);

    const community = await Community.findById(ObjectId(communityId));
    if (!community) return res.status(404).json({ success: false, message: 'Community not found' });

    const alreadyMember = community.members.some(m => String(m.userId) === String(userObjectId));
    if (!alreadyMember) {
      community.members.push({ userId: userObjectId, userName: req.userName || '' });
      await community.save();
    }

    res.json({ success: true, community: formatCommunityForUser(community, req.userId) });
  } catch (err) {
    console.error('Join community error:', err);
    res.status(500).json({ success: false, message: 'Failed to join community' });
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

    return res.status(201).json({
      success: true,
      data: formatCommunityMessage(newMessage)
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
    const { communityId, limit = 50 } = req.query;
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
    const messages = await CommunityMessage.find({ communityId })
      .sort({ createdAt: 1 })
      .limit(parsedLimit)
      .lean();

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

