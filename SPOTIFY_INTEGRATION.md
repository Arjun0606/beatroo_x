# Spotify SDK Integration Guide

To complete the integration with Spotify and enable direct access to Spotify's playback information, follow these steps:

## Step 1: Download the Spotify iOS SDK

1. Go to the Spotify iOS SDK GitHub repository: https://github.com/spotify/ios-sdk
2. Download the latest version (use the green "Code" button and select "Download ZIP")
3. Extract the ZIP file to access the SDK files

## Step 2: Add the SDK to Your Project

1. Open your Xcode project
2. Drag the `SpotifyiOS.xcframework` from the extracted folder into your project
3. Make sure "Copy items if needed" is checked and the target is selected
4. In the "Build Phases" tab of your project settings, confirm that `SpotifyiOS.xcframework` appears under "Link Binary With Libraries"

## Step 3: Update the Bridging Header

1. Open the `Beatroo-Bridging-Header.h` file
2. Uncomment the line: `#import <SpotifyiOS/SpotifyiOS.h>`

## Step 4: Configure Your Spotify Developer Account

1. Go to the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard/)
2. Create a new app (or use an existing one)
3. Set the Redirect URI to `beatroo://spotify-callback`
4. Note your Client ID

## Step 5: Update the SpotifyManager Class

1. Open `SpotifyManager.swift`
2. Replace `YOUR_SPOTIFY_CLIENT_ID` with your actual Spotify Client ID
3. Remove the placeholder implementation and uncomment the full implementation code at the bottom of the file (or replace it with the full implementation)

## Step 6: Update Info.plist (Already Done)

We've already updated the Info.plist with:

- `LSApplicationQueriesSchemes` to include `spotify` for detecting the Spotify app
- `CFBundleURLTypes` to include the `beatroo` scheme for handling callbacks

## Using the Integration

The `MusicServiceCoordinator` now manages all music services including Spotify. When a user is playing music through Spotify, the app will:

1. Detect that Spotify is the current music provider
2. Display the correct information about the currently playing track
3. Show the Spotify branding and colors

## Troubleshooting

- If Spotify integration doesn't work, make sure:
  - The Spotify app is installed on the device
  - You've entered the correct Client ID
  - The redirect URI in your Spotify Developer Dashboard matches the one in the code
  - The user has logged into their Spotify account in the Spotify app

## Additional Music Services

The app is now configured to detect music from:

- Apple Music (built-in)
- Spotify (requires SDK for full functionality)
- YouTube Music (basic detection)
- Amazon Music (basic detection)

Each service has its own manager class that can be extended with more features as needed. 