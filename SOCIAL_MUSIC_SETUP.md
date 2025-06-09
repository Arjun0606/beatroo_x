# Social Music Features Setup Guide

## Overview
This guide will help you deploy the new social music discovery features to your Beatroo app. These features include:

- **Nearby Music Discovery**: Find users within 35 meters and see what they're listening to
- **Like System**: "Vibe" with others' music taste
- **Play Tracking**: Track when users listen to your music
- **Daily Leaderboards**: City-based rankings with points (likes=1pt, plays=2pts)
- **Real-time Notifications**: Get notified when someone vibes with your music

## 1. Update Firestore Security Rules

### Option A: Firebase Console (Recommended)
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your Beatroo project
3. Navigate to **Firestore Database** → **Rules**
4. Copy the contents of `firestore_rules_social_music.rules` and paste into the rules editor
5. Click **Publish**

### Option B: Firebase CLI
```bash
# Copy the rules file to your project
cp firestore_rules_social_music.rules firestore.rules

# Deploy the rules
firebase deploy --only firestore:rules
```

## 2. Add Location Permissions to Info.plist

Add these entries to your `Info.plist` file:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Beatroo uses your location to discover nearby music listeners and connect you with others in your area.</string>

<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>Beatroo uses your location to discover nearby music listeners and connect you with others in your area.</string>
```

## 3. New Firestore Collections Created

The app will automatically create these collections when users interact with the features:

- **`user_current_activity`**: Real-time music sharing (updates every 30 seconds)
- **`music_likes`**: Individual like interactions
- **`music_plays`**: Play tracking when users listen to others' music
- **`music_notifications`**: User notifications for social interactions

## 4. Privacy Considerations

- **Location**: Only city/country are stored, not exact coordinates
- **Music Data**: Only current track info is shared (title, artist, album)
- **Discovery Radius**: Limited to 35 meters for privacy
- **User Control**: Users can stop sharing by disconnecting music services

## 5. Testing Checklist

### Location Features
- [ ] App requests location permission
- [ ] Location manager starts detecting nearby users
- [ ] City detection works for leaderboards

### Social Music
- [ ] Current music appears in nearby view when playing
- [ ] Like button works and sends notifications
- [ ] Play tracking works when listening to others' music
- [ ] Leaderboard shows correct scores

### Notifications
- [ ] Notifications appear when receiving likes/plays
- [ ] Notification badges update tab bar
- [ ] Notification history persists correctly

## 6. Performance Notes

- **Real-time Updates**: Music activity syncs every 30 seconds when active
- **Location Batching**: Location updates are throttled to preserve battery
- **Firestore Limits**: Current design supports ~100 concurrent users per city
- **Background Sync**: Music sharing stops when app is backgrounded

## 7. Future Enhancements

Consider implementing these features:
- Push notifications for social interactions
- Friend system with follow/following
- Music taste compatibility scores
- Weekly/monthly leaderboards
- Group listening sessions

## 8. Troubleshooting

### Common Issues

**Location not working:**
- Check Info.plist permissions are added
- Verify user granted location access in Settings
- Test on physical device (location doesn't work in simulator)

**Firestore permission errors:**
- Ensure new rules are deployed
- Check user is authenticated
- Verify rule syntax is correct

**Music not sharing:**
- Confirm music service is connected (Spotify/Apple Music)
- Check music is actively playing
- Verify internet connection for Firestore sync

## Support

If you encounter issues:
1. Check the Xcode console for error messages
2. Verify Firestore rules in Firebase Console
3. Test location permissions in device Settings
4. Ensure music services are properly connected 