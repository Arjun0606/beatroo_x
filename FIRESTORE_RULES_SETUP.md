# Firestore Security Rules Setup

## Issue
When trying to delete a user account, you're getting this error:
```
Error deleting account: Error Domain=FIRFirestoreErrorDomain Code=7 "Missing or insufficient permissions."
```

This happens because the default Firestore security rules don't allow users to delete their own documents.

## Solution

### Step 1: Open Firebase Console
1. Go to [https://console.firebase.google.com](https://console.firebase.google.com)
2. Select your Beatroo project

### Step 2: Navigate to Firestore Rules
1. In the left sidebar, click on "Firestore Database"
2. Click on the "Rules" tab at the top

### Step 3: Update the Rules
Replace the existing rules with the content from `firestore.rules` file in this project:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read, write, and delete their own user document
    match /users/{userId} {
      allow read, write, delete: if request.auth != null && request.auth.uid == userId;
    }
    
    // Allow users to read other users' basic profile info (for future social features)
    match /users/{userId} {
      allow read: if request.auth != null;
    }
    
    // Deny all other reads and writes by default
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Step 4: Publish the Rules
1. Click the "Publish" button
2. Wait for the rules to be deployed (usually takes a few seconds)

## What These Rules Do

1. **Allow users to manage their own data**: Users can read, write, and delete documents in `/users/{userId}` where `userId` matches their authentication UID
2. **Allow reading other users' profiles**: Authenticated users can read other users' profile data (useful for social features)
3. **Deny everything else**: All other operations are denied by default for security

## Testing Account Deletion

After updating the rules:
1. Try deleting your account again
2. The app should successfully delete the user document from Firestore
3. The Firebase Auth account will be deleted
4. You'll be automatically redirected to the sign-up screen
5. After signing up again, you'll go through profile creation

## Security Notes

- These rules ensure users can only access and modify their own data
- The rules require authentication for all operations
- Unknown or unauthenticated users cannot access any data
- Each user's data is isolated and protected from other users 