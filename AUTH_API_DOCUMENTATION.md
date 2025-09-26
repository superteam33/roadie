# Authentication API Documentation

This document describes the authentication endpoints for the Roadie application, including RSA-encrypted password handling and session management.

## Overview

The authentication system uses:

- **RSA encryption** for secure password transmission
- **Session-based authentication** with access tokens
- **Role-based access control** (admin, manager, member)
- **Automatic session expiration** (24 hours)

## Endpoints

### 1. Get Public Key

**GET** `/api/v1/auth/public_key`

Retrieves the RSA public key for password encryption.

**Response:**

```json
{
  "public_key": "-----BEGIN PUBLIC KEY-----\n...\n-----END PUBLIC KEY-----",
  "message": "Use this public key to encrypt passwords before sending to login/signup endpoints"
}
```

### 2. User Signup

**POST** `/api/v1/auth/signup`

Creates a new user account with RSA-encrypted password.

**Request Body:**

```json
{
  "first_name": "John",
  "last_name": "Doe",
  "email": "john.doe@example.com",
  "role": "member",
  "encrypted_password": "base64_encoded_encrypted_password"
}
```

**Response (Success - 201):**

```json
{
  "message": "User created successfully",
  "user": {
    "data": {
      "id": "1",
      "type": "user",
      "attributes": {
        "id": 1,
        "first_name": "John",
        "last_name": "Doe",
        "email": "john.doe@example.com",
        "role": "member",
        "created_at": "2025-09-24T04:16:01.231Z",
        "updated_at": "2025-09-24T04:16:01.231Z",
        "full_name": "John Doe",
        "integration_tokens": {}
      }
    }
  },
  "access_token": "sGhSUFdZ-KKrxvyzQ9SHQqEhBDrZvyoTZVzjfKgBLL0",
  "expires_at": "2025-09-25T04:16:01.253Z"
}
```

**Response (Error - 422):**

```json
{
  "error": "Failed to create user",
  "details": ["Email has already been taken", "First name can't be blank"]
}
```

### 3. User Login

**POST** `/api/v1/auth/login`

Authenticates a user with RSA-encrypted password.

**Request Body:**

```json
{
  "email": "john.doe@example.com",
  "encrypted_password": "base64_encoded_encrypted_password"
}
```

**Response (Success - 200):**

```json
{
  "message": "Login successful",
  "user": {
    "data": {
      "id": "1",
      "type": "user",
      "attributes": {
        "id": 1,
        "first_name": "John",
        "last_name": "Doe",
        "email": "john.doe@example.com",
        "role": "member",
        "created_at": "2025-09-24T04:16:01.231Z",
        "updated_at": "2025-09-24T04:16:01.231Z",
        "full_name": "John Doe",
        "integration_tokens": {}
      }
    }
  },
  "access_token": "sGhSUFdZ-KKrxvyzQ9SHQqEhBDrZvyoTZVzjfKgBLL0",
  "expires_at": "2025-09-25T04:16:01.253Z"
}
```

**Response (Error - 401):**

```json
{
  "error": "Invalid email or password"
}
```

### 4. Get Current User

**GET** `/api/v1/auth/me`

**Headers:**

```
Authorization: Bearer <access_token>
```

**Response (Success - 200):**

```json
{
  "user": {
    "data": {
      "id": "1",
      "type": "user",
      "attributes": {
        "id": 1,
        "first_name": "John",
        "last_name": "Doe",
        "email": "john.doe@example.com",
        "role": "member",
        "created_at": "2025-09-24T04:16:01.231Z",
        "updated_at": "2025-09-24T04:16:01.231Z",
        "full_name": "John Doe",
        "integration_tokens": {}
      }
    }
  },
  "session": {
    "access_token": "sGhSUFdZ-KKrxvyzQ9SHQqEhBDrZvyoTZVzjfKgBLL0",
    "expires_at": "2025-09-25T04:16:01.253Z"
  }
}
```

**Response (Error - 401):**

```json
{
  "error": "Unauthorized"
}
```

### 5. User Logout

**POST** `/api/v1/auth/logout`

**Headers:**

```
Authorization: Bearer <access_token>
```

**Response (Success - 200):**

```json
{
  "message": "Logged out successfully"
}
```

**Response (Error - 401):**

```json
{
  "error": "Unauthorized"
}
```

## Client Implementation

### Password Encryption

Before sending passwords to the server, clients must:

1. **Get the public key:**

   ```javascript
   const response = await fetch("/api/v1/auth/public_key");
   const { public_key } = await response.json();
   ```

2. **Encrypt the password:**

   ```javascript
   // Using Web Crypto API or a library like node-rsa
   const encrypted = await encryptPassword(password, public_key);
   ```

3. **Send the encrypted password:**
   ```javascript
   const response = await fetch("/api/v1/auth/login", {
     method: "POST",
     headers: { "Content-Type": "application/json" },
     body: JSON.stringify({
       email: "user@example.com",
       encrypted_password: encrypted,
     }),
   });
   ```

### Session Management

1. **Store the access token** from login/signup responses
2. **Include the token** in all authenticated requests:
   ```javascript
   headers: {
     'Authorization': `Bearer ${access_token}`
   }
   ```
3. **Handle token expiration** by redirecting to login
4. **Logout** by calling the logout endpoint and clearing stored tokens

## Security Features

- **RSA Encryption**: Passwords are encrypted client-side before transmission
- **Session Management**: Each login creates a new session, invalidating previous ones
- **Token Expiration**: Sessions expire after 24 hours
- **Secure Headers**: All authenticated endpoints require proper Authorization headers
- **Role-based Access**: Users have roles (admin, manager, member) for authorization

## Error Handling

Common error responses:

- **400 Bad Request**: Invalid request format or decryption failure
- **401 Unauthorized**: Invalid credentials or expired/invalid token
- **422 Unprocessable Entity**: Validation errors (duplicate email, missing fields)
- **500 Internal Server Error**: Server-side errors

## Database Schema

### Users Table

- `id` (primary key)
- `first_name` (string, required)
- `last_name` (string, required)
- `email` (string, unique, required)
- `password_digest` (string, required)
- `role` (enum: admin, manager, member)
- `created_at`, `updated_at`

### User Sessions Table

- `id` (primary key)
- `user_id` (foreign key to users)
- `access_token` (string, unique, required)
- `expires_at` (datetime, required)
- `is_active` (boolean, default: true)
- `created_at`, `updated_at`

## Environment Variables

Required environment variables:

- `RSA_PUBLIC_KEY`: RSA public key for password encryption
- `RSA_PRIVATE_KEY`: RSA private key for password decryption
- `JWT_SECRET_KEY`: Secret key for JWT operations (legacy)
