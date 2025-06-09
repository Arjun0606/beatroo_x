import Foundation
import FirebaseFirestore
import FirebaseAuth

@MainActor
class SocialMusicManager: ObservableObject {
    @Published var nearbyUsers: [NearbyUser] = []
    @Published var notifications: [MusicNotification] = []
    @Published var leaderboard: [MusicActivity] = []
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
    }
    
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
            // Save play
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
            
            // Here you would integrate with Spotify/Apple Music to actually play the track
            // For now, we'll just track the play
            print("Playing \(track.title) by \(user.displayName)")
            
        } catch {
            print("Error playing track: \(error)")
            errorMessage = "Failed to play track"
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
            // Get today's start time (midnight)
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: Date())
            
            // Fetch likes from today
            let likesSnapshot = try await db.collection("music_likes")
                .whereField("city", isEqualTo: city)
                .whereField("timestamp", isGreaterThan: startOfDay)
                .getDocuments()
            
            // Fetch plays from today
            let playsSnapshot = try await db.collection("music_plays")
                .whereField("city", isEqualTo: city)
                .whereField("timestamp", isGreaterThan: startOfDay)
                .getDocuments()
            
            // Process and aggregate scores
            var scoreMap: [String: MusicActivity] = [:]
            
            // Process likes
            for doc in likesSnapshot.documents {
                if let like = try? doc.data(as: MusicLike.self) {
                    let key = "\(like.toUserId)-\(like.trackTitle)-\(like.trackArtist)"
                    
                    if var activity = scoreMap[key] {
                        activity = MusicActivity(
                            id: activity.id,
                            userId: activity.userId,
                            username: activity.username,
                            displayName: activity.displayName,
                            profilePhotoURL: activity.profilePhotoURL,
                            trackId: activity.trackId,
                            trackTitle: activity.trackTitle,
                            trackArtist: activity.trackArtist,
                            provider: activity.provider,
                            city: activity.city,
                            country: activity.country,
                            timestamp: activity.timestamp,
                            likes: activity.likes + [like.fromUserId],
                            plays: activity.plays,
                            location: activity.location
                        )
                        scoreMap[key] = activity
                    }
                }
            }
            
            // Process plays
            for doc in playsSnapshot.documents {
                if let play = try? doc.data(as: MusicPlay.self) {
                    let key = "\(play.toUserId)-\(play.trackTitle)-\(play.trackArtist)"
                    
                    if var activity = scoreMap[key] {
                        activity = MusicActivity(
                            id: activity.id,
                            userId: activity.userId,
                            username: activity.username,
                            displayName: activity.displayName,
                            profilePhotoURL: activity.profilePhotoURL,
                            trackId: activity.trackId,
                            trackTitle: activity.trackTitle,
                            trackArtist: activity.trackArtist,
                            provider: activity.provider,
                            city: activity.city,
                            country: activity.country,
                            timestamp: activity.timestamp,
                            likes: activity.likes,
                            plays: activity.plays + [play.fromUserId],
                            location: activity.location
                        )
                        scoreMap[key] = activity
                    }
                }
            }
            
            // Sort by total score
            let sortedActivities = Array(scoreMap.values)
                .sorted { $0.totalScore > $1.totalScore }
                .prefix(50) // Top 50
            
            leaderboard = Array(sortedActivities)
            
        } catch {
            print("Error loading leaderboard: \(error)")
            errorMessage = "Failed to load leaderboard"
        }
        
        isLoading = false
    }
} 