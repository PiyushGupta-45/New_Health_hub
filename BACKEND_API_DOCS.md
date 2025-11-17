# Backend API Documentation

This document describes the API endpoints that your MongoDB Atlas backend needs to implement for the authentication system to work.

## Base URL
All endpoints should be prefixed with your API base URL (set in `.env` file as `API_BASE_URL`).

## Authentication Endpoints

### 1. Sign Up
**POST** `/api/auth/signup`

**Headers:**
```
Content-Type: application/json
x-api-key: <your-api-key> (optional, if you set API_KEY in .env)
```

**Request Body:**
```json
{
  "name": "John Doe",
  "email": "john@example.com",
  "password": "password123"
}
```

**Success Response (201 or 200):**
```json
{
  "success": true,
  "user": {
    "id": "user_id",
    "name": "John Doe",
    "email": "john@example.com",
    "token": "jwt_token_here"
  }
}
```

**Error Response (400/409):**
```json
{
  "success": false,
  "message": "Email already exists"
}
```

### 2. Sign In
**POST** `/api/auth/signin`

**Headers:**
```
Content-Type: application/json
x-api-key: <your-api-key> (optional)
```

**Request Body:**
```json
{
  "email": "john@example.com",
  "password": "password123"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "user": {
    "id": "user_id",
    "name": "John Doe",
    "email": "john@example.com",
    "token": "jwt_token_here"
  }
}
```

**Error Response (401):**
```json
{
  "success": false,
  "message": "Invalid credentials"
}
```

### 3. Google Sign In
**POST** `/api/auth/google`

**Headers:**
```
Content-Type: application/json
x-api-key: <your-api-key> (optional)
```

**Request Body:**
```json
{
  "idToken": "google_id_token",
  "accessToken": "google_access_token",
  "name": "John Doe",
  "email": "john@example.com",
  "photoUrl": "https://..."
}
```

**Success Response (200 or 201):**
```json
{
  "success": true,
  "user": {
    "id": "user_id",
    "name": "John Doe",
    "email": "john@example.com",
    "token": "jwt_token_here"
  }
}
```

## MongoDB Schema Example

Your user collection should have a structure like:
```javascript
{
  _id: ObjectId,
  name: String,
  email: String (unique, indexed),
  password: String (hashed),
  googleId: String (optional, for Google users),
  createdAt: Date,
  updatedAt: Date
}
```

## Implementation Notes

1. **Password Hashing**: Always hash passwords using bcrypt or similar before storing in MongoDB
2. **JWT Tokens**: Generate JWT tokens for authenticated sessions
3. **Email Validation**: Validate email format and check for duplicates
4. **Google OAuth**: Verify Google ID tokens on the backend before creating/updating user accounts
5. **Error Handling**: Return consistent error responses with appropriate HTTP status codes

## Example Backend Stack

You can use any backend framework:
- **Node.js**: Express.js with MongoDB driver or Mongoose
- **Python**: Flask/FastAPI with PyMongo
- **Java**: Spring Boot with MongoDB
- **C#**: ASP.NET Core with MongoDB driver

## Security Best Practices

1. Use HTTPS for all API calls
2. Implement rate limiting
3. Validate and sanitize all inputs
4. Use environment variables for sensitive data
5. Implement proper CORS policies
6. Use secure session management

