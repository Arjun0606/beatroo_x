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
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
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
        // First, check if Spotify is connected and has a current track
        let spotifyHasCurrentTrack = spotifyManager.isConnected && spotifyManager.currentTrack != nil
        
        // PRIORITY 1: Check Apple Music first (highest priority) - BUT only if Spotify doesn't have a current track
        if isAppleMusicActuallyPlaying() && !spotifyHasCurrentTrack {
            if lastProvider != .appleMusicStreaming {
                print("MusicServiceCoordinator: Apple Music is actively playing, switching to Apple Music")
            }
            useAppleMusicTrack()
            return
        }
        
        // PRIORITY 2: Check Spotify if connected (especially if it has a current track)
        if spotifyManager.isConnected {
            print("MusicServiceCoordinator: Spotify is connected, checking for current track...")
            print("MusicServiceCoordinator: Spotify has current track: \(spotifyHasCurrentTrack)")
            if let track = spotifyManager.currentTrack {
                print("MusicServiceCoordinator: Spotify current track: \(track.name) by \(track.artist)")
            } else {
                print("MusicServiceCoordinator: Spotify current track is nil")
            }
            
            // If Spotify already has a track, use it immediately
            if let spotifyTrack = spotifyManager.currentTrack {
                print("MusicServiceCoordinator: 🎵 USING SPOTIFY TRACK: \(spotifyTrack.name) by \(spotifyTrack.artist), playing: \(spotifyManager.isPlaying)")
                DispatchQueue.main.async {
                    self.currentProvider = .spotify
                    self.currentTrack = MusicTrackInfo(
                        title: spotifyTrack.name,
                        artist: spotifyTrack.artist,
                        album: spotifyTrack.album,
                        artwork: spotifyTrack.artworkImage,
                        provider: .spotify
                    )
                    self.isPlaying = self.spotifyManager.isPlaying
                    self.playbackState = self.spotifyManager.isPlaying ? .playing : .paused
                    self.lastProvider = .spotify
                    self.lastTrackTitle = spotifyTrack.name
                }
                return
            }
            
            // Otherwise, request current track and check again after a delay
            spotifyManager.getCurrentTrack()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let spotifyTrack = self.spotifyManager.currentTrack {
                    if self.lastTrackTitle != spotifyTrack.name {
                        print("MusicServiceCoordinator: Using Spotify track (after delay): \(spotifyTrack.name), playing: \(self.spotifyManager.isPlaying)")
                    }
                    DispatchQueue.main.async {
                        self.currentProvider = .spotify
                        self.currentTrack = MusicTrackInfo(
                            title: spotifyTrack.name,
                            artist: spotifyTrack.artist,
                            album: spotifyTrack.album,
                            artwork: spotifyTrack.artworkImage,
                            provider: .spotify
                        )
                        self.isPlaying = self.spotifyManager.isPlaying
                        self.playbackState = self.spotifyManager.isPlaying ? .playing : .paused
                        self.lastProvider = .spotify
                        self.lastTrackTitle = spotifyTrack.name
                    }
                } else {
                    // If Spotify is connected but no track, check Apple Music as fallback
                    if self.isAppleMusicActuallyPlaying() {
                        self.useAppleMusicTrack()
                    } else {
                        if self.lastProvider != .unknown {
                            print("MusicServiceCoordinator: Spotify connected but no track playing")
                        }
                        self.clearCurrentTrack()
                    }
                }
            }
            return
        }
        
        // PRIORITY 3: If Spotify not connected, check Apple Music
        if isAppleMusicActuallyPlaying() {
            if lastProvider != .appleMusicStreaming {
                print("MusicServiceCoordinator: Using Apple Music as fallback")
            }
            useAppleMusicTrack()
            return
        }
        
        // PRIORITY 4: If neither is actively playing, clear the track
        if lastProvider != .unknown {
            print("MusicServiceCoordinator: No active music detected")
        }
        clearCurrentTrack()
    }
    
    private func isAppleMusicActuallyPlaying() -> Bool {
        // Simplified Apple Music detection
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        // Check if we have a track and it's playing or paused (but available)
        let hasSystemTrack = musicPlayer.nowPlayingItem != nil
        let isSystemActive = musicPlayer.playbackState == .playing || musicPlayer.playbackState == .paused
        
        // Check MPNowPlayingInfoCenter
        var hasNowPlayingInfo = false
        if let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            hasNowPlayingInfo = nowPlayingInfo[MPMediaItemPropertyTitle] != nil ||
                               nowPlayingInfo[MPMediaItemPropertyArtist] != nil
        }
        
        // Check our NowPlayingManager
        let hasNowPlayingTrack = nowPlayingManager.currentTrack != nil
        
        // Apple Music is active if ANY of these conditions are true AND we haven't had a recent interruption
        let hasAppleMusicActivity = (hasSystemTrack && isSystemActive) || hasNowPlayingInfo || hasNowPlayingTrack
        let shouldShowAppleMusic = hasAppleMusicActivity && !lastConnectionInterruption
        
        if shouldShowAppleMusic {
            lastAppleMusicUpdate = Date()
            lastConnectionInterruption = false
        }
        
        return shouldShowAppleMusic
    }
    
    private func checkAppleMusicAppStatus() {
        // Simplified Apple Music app status check
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        print("MusicServiceCoordinator: 🔍 Checking Apple Music app status...")
        print("MusicServiceCoordinator: - Playback state: \(musicPlayer.playbackState.rawValue)")
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
                    provider: .appleMusicStreaming
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