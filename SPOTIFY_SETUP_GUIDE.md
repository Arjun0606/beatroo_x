# Complete Spotify SDK Integration Guide for Beatroo

## ✅ What's Already Done

1. ✅ Spotify SDK copied to your project folder
2. ✅ Client ID updated in SpotifyManager (`9b3615b5699e4b8d8da6222ebef7a99c`)
3. ✅ Bridging header updated to import SpotifyiOS
4. ✅ Info.plist configured with URL schemes and app queries
5. ✅ SpotifyManager code ready for SDK integration

## 🔧 Manual Steps Required in Xcode

### Step 1: Add Framework to Xcode Project

1. **Open Xcode** and open your project: `/Users/arjun/BeatrooFinal/Beatroo/Beatroo.xcodeproj`

2. **Add the Framework:**
   - In the Project Navigator (left panel), right-click on the "Beatroo" folder
   - Select "Add Files to 'Beatroo'"
   - Navigate to `/Users/arjun/BeatrooFinal/Beatroo/SpotifyiOS.xcframework`
   - Select it and click "Add"
   - ✅ Make sure "Copy items if needed" is checked
   - ✅ Make sure your "Beatroo" target is selected

3. **Verify Framework is Added:**
   - Go to your project settings (click on "Beatroo" at the top of the Navigator)
   - Select the "Beatroo" target
   - Go to "General" tab
   - Under "Frameworks, Libraries, and Embedded Content", you should see `SpotifyiOS.xcframework`
   - If it's not there, click the "+" button and add it

### Step 2: Configure Build Settings

1. **Set Bridging Header:**
   - In project settings → Beatroo target → "Build Settings" tab
   - Search for "Objective-C Bridging Header"
   - Set the value to: `Beatroo/Beatroo-Bridging-Header/Beatroo-Bridging-Header.h`

2. **Add Linker Flag:**
   - Still in Build Settings, search for "Other Linker Flags"
   - Add `-ObjC` if it's not already there

### Step 3: Update Spotify Developer Dashboard

1. **Go to Spotify Dashboard:**
   - Visit: https://developer.spotify.com/dashboard/9b3615b5699e4b8d8da6222ebef7a99c
   - Click on your "Beatroo" app

2. **Add Redirect URI:**
   - Click "Edit Settings"
   - In "Redirect URIs", add: `beatroo://spotify-callback`
   - Click "Save"

### Step 4: Activate Full Spotify Implementation

Once the framework is properly added to your Xcode project:

1. **Open `/Users/arjun/BeatrooFinal/Beatroo/Beatroo/Managers/SpotifyManager.swift`**

2. **Uncomment the configuration setup** (around line 25):
   ```swift
   // Change this:
   // setupSpotifyConfiguration()
   
   // To this:
   setupSpotifyConfiguration()
   ```

3. **Uncomment the setupSpotifyConfiguration method** (around line 30):
   ```swift
   // Remove the /* and */ around this entire method
   private func setupSpotifyConfiguration() {
       configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURI)
       appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
       (appRemote as! SPTAppRemote).delegate = self
   }
   ```

4. **Uncomment all the SDK-specific code** in the connect(), handleCallback(), and getCurrentTrack() methods

5. **Uncomment the delegate extensions** at the bottom of the file

## 🧪 Testing the Integration

### Step 5: Add Test View (Optional)

You can temporarily add the test view to your main tab view:

1. **Open `/Users/arjun/BeatrooFinal/Beatroo/Beatroo/Views/MainTabView.swift`**

2. **Add a test tab** (temporary for testing):
   ```swift
   SpotifyTestView()
       .tabItem {
           Label("Spotify Test", systemImage: "music.note")
       }
       .tag(2)
   ```

### Step 6: Test on Physical Device

**Important:** You MUST test on a physical iOS device (not simulator) because:
- The Spotify app cannot be installed on the simulator
- URL scheme handling requires a real device

**Testing Steps:**
1. Install the Spotify app on your device from the App Store
2. Log into your Spotify account
3. Build and run your Beatroo app on the device
4. Go to the "Spotify Test" tab (if you added it)
5. You should see "Spotify Installed: ✅"
6. Try playing music in Spotify, then switch back to your app
7. Tap "Refresh Now Playing" to see if it detects the Spotify track

## 🐛 Troubleshooting

### Common Issues:

1. **"No such module 'SpotifyiOS'" error:**
   - Make sure the framework is properly added to your project
   - Check that the bridging header path is correct
   - Clean and rebuild your project (Product → Clean Build Folder)

2. **Bridging header not found:**
   - Verify the path: `Beatroo/Beatroo-Bridging-Header/Beatroo-Bridging-Header.h`
   - Make sure the file exists at that location

3. **Spotify not detecting:**
   - Ensure Spotify is installed and running on your device
   - Check that you've added the redirect URI to your Spotify app settings
   - Make sure the URL scheme is properly configured

4. **App crashes on launch:**
   - This usually means the bridging header or framework setup is incorrect
   - Check the console for specific error messages

## 📱 What Should Work After Integration

✅ **Detect when Spotify is installed**
✅ **Detect when music is playing from Spotify**
✅ **Show Spotify branding and colors in your app**
✅ **Handle authorization flow with Spotify**
✅ **Get current track information from Spotify**
✅ **Control playback (pause, play, skip) through Spotify SDK**

## 🔄 Next Steps After Basic Integration

Once the basic integration is working, you can:

1. Remove the test view and integrate Spotify detection into your main now playing view
2. Add more Spotify-specific features like playlists, search, etc.
3. Implement token refresh for long-term sessions
4. Add error handling for network issues

---

**Need Help?** If you encounter any issues, the console in Xcode will show helpful error messages. The most common issues are related to framework setup or bridging header configuration. 