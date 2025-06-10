import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import UIKit
import MediaPlayer

@MainActor
class SocialMusicManager: ObservableObject {
    @Published var nearbyUsers: [NearbyUser] = []
    @Published var notifications: [MusicNotification] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var nearbyUsersListener: ListenerRegistration?
    private var notificationsListener: ListenerRegistration?
    private var currentUserActivity: MusicActivity?
    
    private var locationManager: LocationManager?
    private var musicCoordinator: MusicServiceCoordinator?
    private var authManager: AuthenticationManager?
    
    init() {
        // Initialize with default values
    }
    
    func initialize(userId: String, musicCoordinator: MusicServiceCoordinator, locationManager: LocationManager) {
        // Store the managers
        self.musicCoordinator = musicCoordinator
        self.locationManager = locationManager
        
        // Get auth manager from current authentication state
        // We'll access the current user through Firebase Auth directly
        
        setupListeners()
        setupLocationObserver()
    }
    
    private func setupLocationObserver() {
        // Observe city changes to reload leaderboard
        guard let locationManager = locationManager else { return }
        
        locationManager.$currentCity
            .removeDuplicates()
            .compactMap { $0 }
            .sink { [weak self] newCity in
                print("City changed to: \(newCity), reloading leaderboard")
                Task { @MainActor in
                    await self?.loadLeaderboard()
                }
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        nearbyUsersListener?.remove()
        notificationsListener?.remove()
    }
    
    private func setupListeners() {
        // Listen for notifications
        setupNotificationsListener()
        
        // Start sharing current music activity
        startSharingMusicActivity()
    }
    
    // MARK: - Music Activity Sharing
    
    private func startSharingMusicActivity() {
        // Update music activity every 30 seconds
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateCurrentMusicActivity()
            }
        }
        
        // Initial update
        Task {
            await updateCurrentMusicActivity()
        }
    }
    
    private func updateCurrentMusicActivity() async {
        guard let user = Auth.auth().currentUser,
              let locationManager = locationManager,
              let musicCoordinator = musicCoordinator,
              let location = locationManager.currentGeoPoint,
              let city = locationManager.currentCity,
              let country = locationManager.currentCountry else {
            return
        }
        
        // Check if user has current track
        if let currentTrack = musicCoordinator.currentTrack,
           musicCoordinator.isPlaying {
            
            let activity = MusicActivity(
                id: UUID().uuidString,
                userId: user.uid,
                username: user.displayName ?? "Unknown",
                displayName: user.displayName ?? "Unknown",
                profilePhotoURL: user.photoURL?.absoluteString,
                trackId: "\(currentTrack.title)-\(currentTrack.artist)",
                trackTitle: currentTrack.title,
                trackArtist: currentTrack.artist,
                provider: currentTrack.providerName,
                city: city,
                country: country,
                timestamp: Date(),
                likes: [],
                plays: [],
                location: location
            )
            
            // Save to Firestore
            do {
                try await saveCurrentActivity(activity)
                currentUserActivity = activity
            } catch {
                print("Error saving music activity: \(error)")
            }
            
        } else {
            // Remove current activity if not playing
            await removeCurrentActivity()
        }
    }
    
    private func saveCurrentActivity(_ activity: MusicActivity) async throws {
        try await db.collection("user_current_activity")
            .document(activity.userId)
            .setData(try Firestore.Encoder().encode(activity))
    }
    
    private func removeCurrentActivity() async {
        guard let user = Auth.auth().currentUser else { return }
        
        do {
            try await db.collection("user_current_activity")
                .document(user.uid)
                .delete()
            currentUserActivity = nil
        } catch {
            print("Error removing current activity: \(error)")
        }
    }
    
    // MARK: - Nearby Users Discovery
    
    func startDiscoveringNearbyUsers() {
        guard let locationManager = locationManager,
              locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            return
        }
        
        nearbyUsersListener = db.collection("user_current_activity")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening to nearby users: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let allUsers = documents.compactMap { doc -> NearbyUser? in
                    do {
                        let activity = try doc.data(as: MusicActivity.self)
                        
                        // Don't include current user
                        if activity.userId == Auth.auth().currentUser?.uid {
                            return nil
                        }
                        
                        let currentTrack = NearbyUser.CurrentTrack(
                            id: activity.trackId,
                            title: activity.trackTitle,
                            artist: activity.trackArtist,
                            album: "", // Not stored in activity
                            provider: activity.provider,
                            artworkURL: nil, // Can be added later
                            isPlaying: true,
                            startedAt: activity.timestamp
                        )
                        
                        return NearbyUser(
                            id: activity.userId,
                            username: activity.username,
                            displayName: activity.displayName,
                            profilePhotoURL: activity.profilePhotoURL,
                            location: activity.location,
                            currentTrack: currentTrack,
                            lastSeen: activity.timestamp,
                            distance: nil // Will be calculated
                        )
                    } catch {
                        print("Error parsing nearby user: \(error)")
                        return nil
                    }
                }
                
                // Filter users within radius
                let nearbyUsers = self.locationManager?.getUsersWithinRadius(allUsers) ?? []
                
                Task { @MainActor in
                    self.nearbyUsers = nearbyUsers
                }
            }
    }
    
    func stopDiscoveringNearbyUsers() {
        nearbyUsersListener?.remove()
        nearbyUsersListener = nil
        nearbyUsers = []
    }
    
    // MARK: - Like System
    
    func likeTrack(_ user: NearbyUser) async {
        guard let currentUser = Auth.auth().currentUser,
              let locationManager = locationManager,
              let track = user.currentTrack,
              let city = locationManager.currentCity else {
            return
        }
        
        let likeId = UUID().uuidString
        let like = MusicLike(
            id: likeId,
            fromUserId: currentUser.uid,
            fromDisplayName: currentUser.displayName ?? "Unknown",
            toUserId: user.id,
            activityId: track.id,
            trackTitle: track.title,
            trackArtist: track.artist,
            timestamp: Date(),
            city: city
        )
        
        do {
            // Save like
            try await db.collection("music_likes").document(likeId).setData(
                try Firestore.Encoder().encode(like)
            )
            
            // Send notification
            await sendNotification(
                to: user.id,
                from: currentUser,
                type: .musicLike,
                track: track
            )
            
            // Award points: 1 point to receiver, 0.25 points to giver
            await awardLikePoints(receiverId: user.id, giverId: currentUser.uid, city: city)
            
            print("Liked \(track.title) by \(user.displayName)")
            
        } catch {
            print("Error liking track: \(error)")
            errorMessage = "Failed to like track"
        }
    }
    
    // MARK: - Play System
    
    func playTrack(_ user: NearbyUser) async {
        guard let currentUser = Auth.auth().currentUser,
              let locationManager = locationManager,
              let track = user.currentTrack,
              let city = locationManager.currentCity else {
            return
        }
        
        // Show provider selection prompt before playing
        await showProviderSelectionPrompt(for: track, user: user, currentUser: currentUser, city: city)
    }
    
    // Enhanced play track with provider selection
    @MainActor
    func showProviderSelectionPrompt(for track: NearbyUser.CurrentTrack, user: NearbyUser, currentUser: FirebaseAuth.User, city: String) async {
        guard let musicCoordinator = musicCoordinator else { return }
        
        // Get available providers
        let availableProviders = musicCoordinator.availableServices
        
        if availableProviders.count == 1 {
            // Only one provider available, use it directly
            await playTrackOnProvider(track, user: user, currentUser: currentUser, city: city, provider: availableProviders[0])
        } else {
            // Multiple providers available, show selection
            let alertController = UIAlertController(
                title: "Choose Music Provider",
                message: "Which app would you like to play \"\(track.title)\" on?",
                preferredStyle: .actionSheet
            )
            
            // Add actions for each available provider
            for provider in availableProviders {
                let action = UIAlertAction(title: provider.displayName, style: .default) { _ in
                    Task {
                        await self.playTrackOnProvider(track, user: user, currentUser: currentUser, city: city, provider: provider)
                    }
                }
                
                // Add provider icon if available
                if let image = provider.iconImage {
                    action.setValue(image, forKey: "image")
                }
                
                alertController.addAction(action)
            }
            
            // Add cancel action
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            
            // Present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                // For iPad support
                if let popover = alertController.popoverPresentationController {
                    popover.sourceView = rootViewController.view
                    popover.sourceRect = CGRect(x: rootViewController.view.bounds.midX, y: rootViewController.view.bounds.midY, width: 0, height: 0)
                    popover.permittedArrowDirections = []
                }
                
                rootViewController.present(alertController, animated: true)
            }
        }
    }
    
    // Actually play the track on the specified provider
    private func playTrackOnProvider(_ track: NearbyUser.CurrentTrack, user: NearbyUser, currentUser: FirebaseAuth.User, city: String, provider: MusicProvider) async {
        let playId = UUID().uuidString
        let play = MusicPlay(
            id: playId,
            fromUserId: currentUser.uid,
            fromDisplayName: currentUser.displayName ?? "Unknown",
            toUserId: user.id,
            activityId: track.id,
            trackTitle: track.title,
            trackArtist: track.artist,
            timestamp: Date(),
            city: city
        )
        
        do {
            // Save play record first
            try await db.collection("music_plays").document(playId).setData(
                try Firestore.Encoder().encode(play)
            )
            
            // Send notification
            await sendNotification(
                to: user.id,
                from: currentUser,
                type: .musicPlay,
                track: track
            )
            
            // Award points: 2 points to receiver, 0.5 points to giver
            await awardPlayPoints(receiverId: user.id, giverId: currentUser.uid, city: city)
            
            // **NEW**: Actually play the track on the chosen provider
            await actuallyPlayTrack(track, on: provider)
            
            print("✅ Playing \(track.title) by \(user.displayName) on \(provider.displayName)")
            
        } catch {
            print("❌ Error playing track: \(error)")
            errorMessage = "Failed to play track on \(provider.displayName)"
        }
    }
    
    // Core method that handles the actual music playback
    @MainActor
    private func actuallyPlayTrack(_ track: NearbyUser.CurrentTrack, on provider: MusicProvider) async {
        guard let musicCoordinator = musicCoordinator else {
            print("❌ MusicServiceCoordinator not available")
            return
        }
        
        switch provider {
        case .spotify:
            await playTrackOnSpotify(track)
            
        case .appleMusicStreaming:
            await playTrackOnAppleMusic(track)
            
        default:
            print("❌ Provider \(provider.displayName) not supported for playback")
            // Open the provider's app as fallback
            musicCoordinator.openMusicApp(provider: provider)
        }
    }
    
    // Spotify-specific playback implementation
    private func playTrackOnSpotify(_ track: NearbyUser.CurrentTrack) async {
        guard let musicCoordinator = musicCoordinator else { return }
        
        let spotifyManager = musicCoordinator.spotifyManager
        
        // Ensure Spotify is connected
        if !spotifyManager.isConnected {
            print("🔗 Spotify not connected, attempting to connect...")
            spotifyManager.connect()
            
            // Wait for connection (with timeout)
            for _ in 0..<10 { // 5 second timeout
                if spotifyManager.isConnected {
                    break
                }
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            if !spotifyManager.isConnected {
                print("❌ Failed to connect to Spotify")
                await showPlaybackError("Unable to connect to Spotify. Please check your connection.")
                return
            }
        }
        
        // Search for the track and play it
        await spotifyManager.searchAndPlayTrack(title: track.title, artist: track.artist)
    }
    
    // Apple Music-specific playback implementation  
    private func playTrackOnAppleMusic(_ track: NearbyUser.CurrentTrack) async {
        // For Apple Music, we'll use the MPMusicPlayerController
        // This requires the track to be in the user's library or Apple Music catalog
        
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        // Search for the track in Apple Music
        let query = MPMediaQuery.songs()
        let titlePredicate = MPMediaPropertyPredicate(value: track.title, forProperty: MPMediaItemPropertyTitle)
        let artistPredicate = MPMediaPropertyPredicate(value: track.artist, forProperty: MPMediaItemPropertyArtist)
        
        query.addFilterPredicate(titlePredicate)
        query.addFilterPredicate(artistPredicate)
        
        if let items = query.items, !items.isEmpty {
            // Found the track in the user's library
            print("🎵 Found \(track.title) in Apple Music library")
            
            let collection = MPMediaItemCollection(items: items)
            musicPlayer.setQueue(with: collection)
            musicPlayer.play()
            
            print("✅ Playing \(track.title) on Apple Music")
        } else {
            // Track not in library, open Apple Music app with search
            print("🔍 Track not in library, opening Apple Music for search")
            
            let searchQuery = "\(track.title) \(track.artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let searchURL = URL(string: "music://search?term=\(searchQuery)") {
                await UIApplication.shared.open(searchURL)
            } else {
                // Fallback to regular Apple Music app
                if let musicURL = URL(string: "music://") {
                    await UIApplication.shared.open(musicURL)
                }
            }
            
            await showPlaybackInfo("Opened Apple Music to search for \"\(track.title)\"")
        }
    }
    
    // Helper methods for user feedback
    @MainActor
    private func showPlaybackError(_ message: String) async {
        let alert = UIAlertController(title: "Playback Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    @MainActor
    private func showPlaybackInfo(_ message: String) async {
        let alert = UIAlertController(title: "Music Player", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }
    
    // MARK: - Notifications
    
    private func sendNotification(to userId: String, from user: FirebaseAuth.User, type: NotificationType, track: NearbyUser.CurrentTrack) async {
        let notificationId = UUID().uuidString
        let message = type == .musicLike ?
            MusicNotification.likeMessage(fromName: user.displayName ?? "Unknown", track: track.title) :
            MusicNotification.playMessage(fromName: user.displayName ?? "Unknown", track: track.title)
        
        let notification = MusicNotification(
            id: notificationId,
            toUserId: userId,
            fromUserId: user.uid,
            fromDisplayName: user.displayName ?? "Unknown",
            type: type,
            trackTitle: track.title,
            trackArtist: track.artist,
            message: message,
            timestamp: Date(),
            isRead: false
        )
        
        do {
            try await db.collection("music_notifications").document(notificationId).setData(
                try Firestore.Encoder().encode(notification)
            )
        } catch {
            print("Error sending notification: \(error)")
        }
    }
    
    private func setupNotificationsListener() {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        notificationsListener = db.collection("music_notifications")
            .whereField("toUserId", isEqualTo: userId)
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error listening to notifications: \(error)")
                    return
                }
                
                guard let documents = snapshot?.documents else { return }
                
                let notifications = documents.compactMap { doc -> MusicNotification? in
                    try? doc.data(as: MusicNotification.self)
                }
                
                Task { @MainActor in
                    self.notifications = notifications
                }
            }
    }
    
    // MARK: - Leaderboard
    
    func loadLeaderboard() async {
        guard let locationManager = locationManager,
              let city = locationManager.currentCity else { return }
        
        isLoading = true
        
        do {
            // Get today's date string
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let todayString = dateFormatter.string(from: Date())
            
            // Load daily leaderboard from Firestore
            let leaderboardDoc = try await db.collection("leaderboards")
                .document(city)
                .collection("daily")
                .document(todayString)
                .getDocument()
            
            if leaderboardDoc.exists,
               let data = leaderboardDoc.data(),
               let dailyLeaderboard = try? Firestore.Decoder().decode(DailyLeaderboard.self, from: data) {
                
                // Use the entries from the daily leaderboard
                leaderboard = dailyLeaderboard.entries.sorted { $0.rank < $1.rank }
                
            } else {
                // No leaderboard exists for today, create empty leaderboard
                print("No leaderboard found for \(city) on \(todayString)")
                leaderboard = []
            }
            
        } catch {
            print("Error loading leaderboard: \(error)")
            errorMessage = "Failed to load leaderboard"
            leaderboard = []
        }
        
        isLoading = false
    }
    
    // MARK: - Points System
    
    private func awardLikePoints(receiverId: String, giverId: String, city: String) async {
        await withTaskGroup(of: Void.self) { group in
            // Award 1 point to the person whose song was liked
            group.addTask {
                await self.awardPoints(userId: receiverId, points: 1.0, reason: "Song liked", city: city)
            }
            
            // Award 0.25 points to the person who liked the song
            group.addTask {
                await self.awardPoints(userId: giverId, points: 0.25, reason: "Liked someone's song", city: city)
            }
        }
    }
    
    private func awardPlayPoints(receiverId: String, giverId: String, city: String) async {
        await withTaskGroup(of: Void.self) { group in
            // Award 2 points to the person whose song was played
            group.addTask {
                await self.awardPoints(userId: receiverId, points: 2.0, reason: "Song played", city: city)
            }
            
            // Award 0.5 points to the person who played the song
            group.addTask {
                await self.awardPoints(userId: giverId, points: 0.5, reason: "Played someone's song", city: city)
            }
        }
    }
    
    private func awardPoints(userId: String, points: Double, reason: String, city: String) async {
        let pointsData: [String: Any] = [
            "userId": userId,
            "points": points,
            "reason": reason,
            "city": city,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        do {
            // Add to points history
            try await db.collection("user_points").addDocument(data: pointsData)
            
            // Update user's total score using a transaction
            try await db.runTransaction { (transaction, errorPointer) -> Any? in
                let userStatsRef = self.db.collection("user_stats").document(userId)
                
                do {
                    let userStatsDoc = try transaction.getDocument(userStatsRef)
                    
                    let currentScore = userStatsDoc.data()?["totalScore"] as? Double ?? 0.0
                    let newScore = currentScore + points
                    
                    let statsData: [String: Any] = [
                        "totalScore": newScore,
                        "lastUpdated": FieldValue.serverTimestamp(),
                        "city": city
                    ]
                    
                    transaction.setData(statsData, forDocument: userStatsRef, merge: true)
                    return nil
                } catch {
                    print("❌ Transaction error: \(error)")
                    return nil
                }
            }
            
            print("✅ Awarded \(points) points to user \(userId) for: \(reason)")
            
        } catch {
            print("❌ Error awarding points: \(error)")
        }
    }
}