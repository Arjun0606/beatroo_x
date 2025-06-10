import SwiftUI
import MediaPlayer

class MusicServiceCoordinator: ObservableObject {
    // Main published properties
    @Published var currentTrack: MusicTrackInfo?
    @Published var currentProvider: MusicProvider = .unknown
    @Published var isPlaying = false
    @Published var playbackState: PlaybackState = .stopped
    
    // Managers for Apple Music and Spotify only
    private let nowPlayingManager = NowPlayingManager()
    let spotifyManager = SpotifyManager() // Made public so NowPlayingManager can access it
    
    // Available services (simplified to just Apple Music and Spotify)
    @Published var availableServices: [MusicProvider] = []
    
    // Timer for periodic updates
    private var updateTimer: Timer?
    
    // Track last state to avoid excessive logging
    private var lastProvider: MusicProvider = .unknown
    private var lastTrackTitle: String?
    private var lastConnectionInterruption = false
    private var lastAppleMusicUpdate: Date?
    
    // Last known states for comparison
    private var lastSpotifyPlayingState: Bool = false
    private var lastAppleMusicPlayingState: Bool = false
    private var lastSpotifyTrackID: String?
    private var lastAppleMusicTrackID: String?
    private var lastAppleMusicUpdateTime: Date = Date()
    
    init() {
        print("MusicServiceCoordinator: Initializing")
        setupObservers()
        detectAvailableServices()
        
        // Give NowPlayingManager access to spotify manager for detection
        nowPlayingManager.setSpotifyManager(spotifyManager)
        
        // Don't auto-connect to Spotify on startup - user should control this
        
        // Start periodic updates to handle state changes
        startPeriodicUpdates()
        
        // Listen for system music player interruptions
        setupInterruptionDetection()
    }
    
    private func startPeriodicUpdates() {
        // **REDUCED INTERVAL**: Check every 2 seconds instead of 3 for smoother transitions
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateCurrentTrack()
        }
    }
    
    private func setupInterruptionDetection() {
        // Listen for various Apple Music interruption signals
        let notificationNames: [NSNotification.Name] = [
            NSNotification.Name("systemMusicPlayer connection interrupted"),
            NSNotification.Name.MPMusicPlayerControllerPlaybackStateDidChange,
            NSNotification.Name.MPMusicPlayerControllerNowPlayingItemDidChange
        ]
        
        for notificationName in notificationNames {
            NotificationCenter.default.addObserver(
                forName: notificationName,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                print("MusicServiceCoordinator: 📡 Received notification: \(notificationName)")
                
                if notificationName.rawValue.contains("interrupted") {
                    print("MusicServiceCoordinator: 🚨 System music player connection interrupted - Apple Music likely killed")
                    self?.lastConnectionInterruption = true
                    
                    // Clear track after delay to allow for app restart
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        if self?.lastConnectionInterruption == true && self?.currentProvider == .appleMusicStreaming {
                            print("MusicServiceCoordinator: Clearing Apple Music track due to sustained interruption")
                            self?.clearCurrentTrack()
                        }
                    }
                } else {
                    // For other notifications, check if Apple Music app is actually running
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.checkAppleMusicAppStatus()
                    }
                }
            }
        }
    }
    
    private func setupObservers() {
        // Observe NowPlayingManager for track updates
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("MPNowPlayingInfoDidChange"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateCurrentTrack()
        }
        
        // **ENHANCED**: More responsive Apple Music detection
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("MusicServiceCoordinator: 📡 Apple Music track changed - forcing immediate update")
            // When Apple Music track changes, mark it as a recent update
            self?.lastAppleMusicUpdateTime = Date()
            self?.updateCurrentTrack()
        }
        
        NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("MusicServiceCoordinator: 📡 Apple Music playback state changed - updating")
            self?.lastAppleMusicUpdateTime = Date()
            self?.updateCurrentTrack()
        }
        
        // Observe Spotify connection changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SpotifyConnectionChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("MusicServiceCoordinator: Spotify connection changed, updating track info")
            
            // Force Spotify to get current track immediately when connection changes
            if let spotifyManager = self?.spotifyManager, spotifyManager.isConnected {
                print("MusicServiceCoordinator: Spotify connected - getting current track")
                spotifyManager.getCurrentTrack()
                
                // Double-check after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.updateCurrentTrack()
                }
            } else {
                print("MusicServiceCoordinator: Spotify disconnected - will only reconnect on manual request")
            }
            
            self?.updateCurrentTrack()
        }
        
        // Observe Spotify track changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SpotifyTrackChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("MusicServiceCoordinator: Spotify track changed, forcing track update")
            self?.updateCurrentTrack()
        }
    }
    
    private func detectAvailableServices() {
        var services: [MusicProvider] = [.appleMusicStreaming] // Apple Music is always available
        
        if spotifyManager.checkSpotifyInstalled() {
            services.append(.spotify)
        }
        
        DispatchQueue.main.async {
            self.availableServices = services
        }
    }
    
    func updateCurrentTrack() {
        print("MusicServiceCoordinator: 🔄 Updating current track - checking both services equally")
        
        // Check both services simultaneously
        // Only consider Spotify connected if it's actually connected (not just has credentials)
        let spotifyConnected = spotifyManager.isConnected
        let spotifyTrack = spotifyManager.currentTrack
        let spotifyPlaying = spotifyManager.isPlaying
        
        let appleMusicTrack = nowPlayingManager.currentTrack
        let appleMusicPlaying = isAppleMusicActuallyPlaying()
        
        print("MusicServiceCoordinator: Spotify - Connected: \(spotifyConnected), Track: \(spotifyTrack?.name ?? "none"), Playing: \(spotifyPlaying)")
        print("MusicServiceCoordinator: Apple Music - Track: \(appleMusicTrack?.title ?? "none"), Playing: \(appleMusicPlaying)")
        
        // Determine which services are actively playing
        let spotifyActivelyPlaying = spotifyConnected && spotifyPlaying && spotifyTrack != nil
        let appleMusicActivelyPlaying = appleMusicPlaying && appleMusicTrack != nil
        
        // **ENHANCED CONFLICT RESOLUTION**: Better handling of service switching
        var useSpotify = false
        var useAppleMusic = false
        
        if spotifyActivelyPlaying && appleMusicActivelyPlaying {
            print("MusicServiceCoordinator: 🤔 Both services claim to be playing")
            
            // Check if user recently switched to Apple Music
            let timeSinceLastAppleMusicUpdate = abs(lastAppleMusicUpdateTime.timeIntervalSinceNow)
            let userJustSwitchedToAppleMusic = timeSinceLastAppleMusicUpdate < 3.0 && lastProvider == .spotify
            
            if userJustSwitchedToAppleMusic {
                useAppleMusic = true
                print("MusicServiceCoordinator: ✅ CONFLICT RESOLUTION: User just switched to Apple Music from Spotify")
            } else {
                // Default preference for actively connected Spotify
                useSpotify = true
                print("MusicServiceCoordinator: ✅ CONFLICT RESOLUTION: Preferring Spotify (actively connected)")
            }
        } else if spotifyActivelyPlaying {
            useSpotify = true
            print("MusicServiceCoordinator: ✅ Only Spotify is actively playing")
        } else if appleMusicActivelyPlaying {
            useAppleMusic = true
            print("MusicServiceCoordinator: ✅ Only Apple Music is actively playing")
        }
        
        // Update current track based on decision
        if useSpotify && spotifyTrack != nil {
            print("MusicServiceCoordinator: 🎵 DISPLAYING SPOTIFY: \(spotifyTrack!.name) by \(spotifyTrack!.artist)")
            DispatchQueue.main.async {
                self.currentTrack = MusicTrackInfo(
                    title: spotifyTrack!.name,
                    artist: spotifyTrack!.artist,
                    album: spotifyTrack!.album,
                    artwork: spotifyTrack!.artworkImage,
                    provider: .spotify,
                    isPlaying: spotifyPlaying
                )
                self.isPlaying = spotifyPlaying
                self.currentProvider = .spotify
                self.playbackState = spotifyPlaying ? .playing : .paused
                
                // Update last known states
                self.lastProvider = .spotify
                self.lastSpotifyPlayingState = spotifyPlaying
            }
        } else if useAppleMusic && appleMusicTrack != nil {
            print("MusicServiceCoordinator: 🎵 DISPLAYING APPLE MUSIC: \(appleMusicTrack!.title) by \(appleMusicTrack!.artist)")
            DispatchQueue.main.async {
                self.currentTrack = MusicTrackInfo(
                    title: appleMusicTrack!.title,
                    artist: appleMusicTrack!.artist,
                    album: appleMusicTrack!.album,
                    artwork: appleMusicTrack!.artwork,
                    provider: .appleMusicStreaming,
                    isPlaying: appleMusicPlaying
                )
                self.isPlaying = appleMusicPlaying
                self.currentProvider = .appleMusicStreaming
                self.playbackState = appleMusicPlaying ? .playing : .paused
                
                // Update last known states  
                self.lastProvider = .appleMusicStreaming
                self.lastAppleMusicPlayingState = appleMusicPlaying
                self.lastAppleMusicUpdateTime = Date() // Track when Apple Music was last updated
            }
        } else {
            // **FIX**: Check if we have a paused track from either service
            // If Spotify is connected but paused, keep showing the track
            if spotifyConnected && spotifyTrack != nil && !spotifyPlaying {
                print("MusicServiceCoordinator: 🎵 DISPLAYING PAUSED SPOTIFY: \(spotifyTrack!.name) by \(spotifyTrack!.artist)")
                DispatchQueue.main.async {
                    self.currentTrack = MusicTrackInfo(
                        title: spotifyTrack!.name,
                        artist: spotifyTrack!.artist,
                        album: spotifyTrack!.album,
                        artwork: spotifyTrack!.artworkImage,
                        provider: .spotify,
                        isPlaying: false
                    )
                    self.isPlaying = false
                    self.currentProvider = .spotify
                    self.playbackState = .paused
                    self.lastProvider = .spotify
                }
            }
            // If Apple Music has a track but is paused, only show it if it's recently paused (not stale cache)
            else if appleMusicTrack != nil && !appleMusicPlaying {
                let timeSinceLastUpdate = abs(lastAppleMusicUpdateTime.timeIntervalSinceNow)
                let isRecentlyPaused = timeSinceLastUpdate < 30.0 // Only show paused tracks from last 30 seconds
                
                if isRecentlyPaused {
                    print("MusicServiceCoordinator: 🎵 DISPLAYING PAUSED APPLE MUSIC: \(appleMusicTrack!.title) by \(appleMusicTrack!.artist)")
                    DispatchQueue.main.async {
                        self.currentTrack = MusicTrackInfo(
                            title: appleMusicTrack!.title,
                            artist: appleMusicTrack!.artist,
                            album: appleMusicTrack!.album,
                            artwork: appleMusicTrack!.artwork,
                            provider: .appleMusicStreaming,
                            isPlaying: false
                        )
                        self.isPlaying = false
                        self.currentProvider = .appleMusicStreaming
                        self.playbackState = .paused
                        self.lastProvider = .appleMusicStreaming
                    }
                } else {
                    print("MusicServiceCoordinator: 🚫 Apple Music track is stale cache (\(timeSinceLastUpdate)s old) - ignoring")
                    clearCurrentTrack()
                }
            }
            // Only clear if we truly have no track from either service
            else {
                print("MusicServiceCoordinator: ❌ No track available from any service")
                clearCurrentTrack()
            }
        }
        
        // Update state tracking for next comparison
        lastSpotifyPlayingState = spotifyPlaying
        lastAppleMusicPlayingState = appleMusicPlaying
    }
    
    private func isAppleMusicActuallyPlaying() -> Bool {
        print("MusicServiceCoordinator: 🔍 Checking Apple Music status...")
        
        let playbackState = nowPlayingManager.playbackState
        let hasNowPlayingItem = nowPlayingManager.currentTrack != nil
        
        print("MusicServiceCoordinator: - Apple Music playback state: \(playbackState)")
        print("MusicServiceCoordinator: - Apple Music has track: \(hasNowPlayingItem)")
        
        // Basic check: must be playing and have a track
        let isReallyPlaying = playbackState == .playing && hasNowPlayingItem
        
        // **IMPROVED FIX**: More balanced logic between Spotify and Apple Music
        if spotifyManager.isConnected && spotifyManager.isPlaying && spotifyManager.currentTrack != nil {
            print("MusicServiceCoordinator: - 🎯 SPOTIFY IS ACTIVELY PLAYING - being skeptical of Apple Music")
            
            // Check if Apple Music track actually changed recently (last 10 seconds instead of 5)
            let timeSinceLastUpdate = abs(lastAppleMusicUpdateTime.timeIntervalSinceNow)
            let reasonablyRecentUpdate = timeSinceLastUpdate < 10.0
            
            // MORE IMPORTANT: Check if Apple Music is ACTUALLY playing (not just paused)
            if playbackState != .playing {
                print("MusicServiceCoordinator: - 🚫 Apple Music is not actively playing (\(playbackState)) while Spotify is active")
                return false
            }
            
            if !reasonablyRecentUpdate {
                print("MusicServiceCoordinator: - 🚫 Apple Music data is stale (\(timeSinceLastUpdate)s old) while Spotify actively playing")
                return false
            }
            
            print("MusicServiceCoordinator: - ✅ Apple Music data is fresh AND actively playing, considering it valid")
        }
        
        print("MusicServiceCoordinator: - Final Apple Music status: \(isReallyPlaying)")
        return isReallyPlaying
    }
    
    private func checkAppleMusicAppStatus() {
        // Simplified Apple Music app status check
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        print("MusicServiceCoordinator: 🔍 Checking Apple Music app status...")
        print("MusicServiceCoordinator: - Playback state: \(musicPlayer.playbackState)")
        print("MusicServiceCoordinator: - Has now playing item: \(musicPlayer.nowPlayingItem != nil)")
        
        // If we have a connection interruption and we're showing Apple Music, clear it
        if lastConnectionInterruption && currentProvider == .appleMusicStreaming {
            print("MusicServiceCoordinator: ❌ Connection was interrupted - clearing track")
            clearCurrentTrack()
            return
        }
        
        // If Apple Music is stopped and we're showing it, clear the track
        if musicPlayer.playbackState == .stopped && currentProvider == .appleMusicStreaming {
            print("MusicServiceCoordinator: ❌ Apple Music stopped - clearing track")
            clearCurrentTrack()
        }
    }
    
    private func useAppleMusicTrack() {
        if let nowPlayingTrack = nowPlayingManager.currentTrack {
            if lastTrackTitle != nowPlayingTrack.title {
                print("MusicServiceCoordinator: Using Apple Music track: \(nowPlayingTrack.title)")
            }
            
            // Update last activity timestamp
            lastAppleMusicUpdate = Date()
            lastConnectionInterruption = false // Reset interruption flag when we get valid data
            
            // Get current playback state from multiple sources for reliability
            let managerIsPlaying = nowPlayingManager.playbackState == .playing
            let systemIsPlaying = MPMusicPlayerController.systemMusicPlayer.playbackState == .playing
            
            // Use the most reliable indicator
            let actuallyPlaying = systemIsPlaying || managerIsPlaying
            
            print("MusicServiceCoordinator: Apple Music playback state - Manager: \(managerIsPlaying), System: \(systemIsPlaying), Final: \(actuallyPlaying)")
            
            DispatchQueue.main.async {
                self.currentProvider = .appleMusicStreaming
                self.currentTrack = MusicTrackInfo(
                    title: nowPlayingTrack.title,
                    artist: nowPlayingTrack.artist,
                    album: nowPlayingTrack.album,
                    artwork: nowPlayingTrack.artwork,
                    provider: .appleMusicStreaming,
                    isPlaying: actuallyPlaying
                )
                self.isPlaying = actuallyPlaying
                self.playbackState = actuallyPlaying ? .playing : .paused
                self.lastProvider = .appleMusicStreaming
                self.lastTrackTitle = nowPlayingTrack.title
            }
        } else {
            clearCurrentTrack()
        }
    }
    
    private func clearCurrentTrack() {
        if lastProvider != .unknown {
            print("MusicServiceCoordinator: Clearing current track")
        }
        DispatchQueue.main.async {
            self.currentTrack = nil
            self.currentProvider = .unknown
            self.isPlaying = false
            self.playbackState = .stopped
            self.lastProvider = .unknown
            self.lastTrackTitle = nil
            self.lastSpotifyPlayingState = false
            self.lastAppleMusicPlayingState = false
            self.lastSpotifyTrackID = nil
            self.lastAppleMusicTrackID = nil
        }
    }
    
    // Handle callback URL for Spotify authorization
    func handleCallback(url: URL) {
        if url.absoluteString.contains("spotify") {
            let success = spotifyManager.handleCallback(url: url)
            if success {
                // Refresh track info after successful connection
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.updateCurrentTrack()
                }
            }
        }
    }
    
    // Connect to Spotify
    func connectToSpotify() {
        spotifyManager.connectWithPersistence()
    }
    
    // Open the appropriate music app
    func openMusicApp(provider: MusicProvider) {
        switch provider {
        case .spotify:
            if let url = URL(string: "spotify:") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        case .appleMusicStreaming:
            if let url = URL(string: "music:") {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        default:
            break
        }
    }
    
    func refreshNowPlaying() {
        print("MusicServiceCoordinator: Refreshing now playing")
        updateCurrentTrack()
    }
    
    // Public method to force refresh current track
    func forceRefresh() {
        print("MusicServiceCoordinator: 🔄 FORCE REFRESH REQUESTED")
        
        // Force Spotify to get current track if connected
        if spotifyManager.isConnected {
            print("MusicServiceCoordinator: Forcing Spotify getCurrentTrack")
            spotifyManager.getCurrentTrack()
        }
        
        // Clear any cached state
        lastProvider = .unknown
        lastTrackTitle = nil
        
        // Force immediate update
        updateCurrentTrack()
    }
    
    // Public method to force Spotify reauthorization
    func forceSpotifyReauthorization() {
        print("MusicServiceCoordinator: 🔑 FORCING SPOTIFY REAUTHORIZATION")
        spotifyManager.forceReauthorization()
    }
    
    // MARK: - Playback Controls
    func togglePlayback() {
        print("MusicServiceCoordinator: Toggle playback requested")
        
        // Store current track info to prevent clearing on state change
        let currentTrackBackup = currentTrack
        let currentProviderBackup = currentProvider
        
        // Simple, direct approach to avoid threading issues
        if spotifyManager.isConnected && currentProvider == .spotify {
            print("MusicServiceCoordinator: Using Spotify controls")
            spotifyManager.togglePlayback()
        } else {
            print("MusicServiceCoordinator: Using system controls")
            nowPlayingManager.togglePlayback()
            
            // For Apple Music, immediately update the play state to prevent UI flickering
            DispatchQueue.main.async {
                if currentTrackBackup != nil && currentProviderBackup == .appleMusicStreaming {
                    self.isPlaying = !self.isPlaying
                    self.playbackState = self.isPlaying ? .playing : .paused
                }
            }
        }
        
        // Update state after a short delay, but preserve track info
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Only refresh if we still have the same track to prevent clearing
            if self.currentTrack?.title == currentTrackBackup?.title {
                self.updateCurrentTrack()
            }
        }
    }
    
    func skipToNextTrack() {
        print("MusicServiceCoordinator: Skip to next track requested")
        
        if spotifyManager.isConnected && currentProvider == .spotify {
            spotifyManager.skipToNextTrack()
        } else {
            nowPlayingManager.skipToNextTrack()
        }
        
        // Update current track after skip
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateCurrentTrack()
        }
    }
    
    func skipToPreviousTrack() {
        print("MusicServiceCoordinator: Skip to previous track requested")
        
        if spotifyManager.isConnected && currentProvider == .spotify {
            spotifyManager.skipToPreviousTrack()
        } else {
            nowPlayingManager.skipToPreviousTrack()
        }
        
        // Update current track after skip
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.updateCurrentTrack()
        }
    }
    
    deinit {
        updateTimer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

// Unified model for track information regardless of source
struct MusicTrackInfo {
    let title: String
    let artist: String
    let album: String
    let artwork: UIImage?
    let provider: MusicProvider
    let isPlaying: Bool
    
    var providerName: String {
        return provider.rawValue
    }
    
    var providerColor: Color {
        return provider.color
    }
    
    // UI compatibility properties
    var platform: String {
        return providerName
    }
    
    var musicProvider: MusicProvider {
        return provider
    }
} 