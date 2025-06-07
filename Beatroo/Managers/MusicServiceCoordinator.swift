import SwiftUI
import MediaPlayer

class MusicServiceCoordinator: ObservableObject {
    // Main published properties
    @Published var currentTrack: MusicTrackInfo?
    @Published var currentProvider: MusicProvider = .unknown
    @Published var isPlaying = false
    
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
    
    init() {
        print("MusicServiceCoordinator: Initializing")
        setupObservers()
        detectAvailableServices()
        
        // Give NowPlayingManager access to spotify manager for detection
        nowPlayingManager.setSpotifyManager(spotifyManager)
        
        // Try to reconnect Spotify if possible
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.spotifyManager.reconnectIfPossible()
        }
        
        // Start periodic updates to handle state changes
        startPeriodicUpdates()
    }
    
    private func startPeriodicUpdates() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateCurrentTrack()
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
        
        // Observe Spotify track changes
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SpotifyTrackChanged"),
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
            print("MusicServiceCoordinator: Spotify connection changed, forcing track update")
            
            // Force Spotify to get current track immediately when connection changes
            if let spotifyManager = self?.spotifyManager, spotifyManager.isConnected {
                print("MusicServiceCoordinator: Forcing Spotify to get current track immediately")
                spotifyManager.getCurrentTrack()
                
                // Double-check after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.updateCurrentTrack()
                }
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
                print("MusicServiceCoordinator: 🎵 USING SPOTIFY TRACK: \(spotifyTrack.name) by \(spotifyTrack.artist)")
                self.currentProvider = .spotify
                self.currentTrack = MusicTrackInfo(
                    title: spotifyTrack.name,
                    artist: spotifyTrack.artist,
                    album: spotifyTrack.album,
                    artwork: spotifyTrack.artworkImage,
                    provider: .spotify
                )
                self.isPlaying = true
                self.lastProvider = .spotify
                self.lastTrackTitle = spotifyTrack.name
                return
            }
            
            // Otherwise, request current track and check again after a delay
            spotifyManager.getCurrentTrack()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                if let spotifyTrack = self.spotifyManager.currentTrack {
                    if self.lastTrackTitle != spotifyTrack.name {
                        print("MusicServiceCoordinator: Using Spotify track (after delay): \(spotifyTrack.name)")
                    }
                    self.currentProvider = .spotify
                    self.currentTrack = MusicTrackInfo(
                        title: spotifyTrack.name,
                        artist: spotifyTrack.artist,
                        album: spotifyTrack.album,
                        artwork: spotifyTrack.artworkImage,
                        provider: .spotify
                    )
                    self.isPlaying = true
                    self.lastProvider = .spotify
                    self.lastTrackTitle = spotifyTrack.name
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
        // EXTREMELY strict detection - Apple Music must be ACTIVELY playing RIGHT NOW
        let musicPlayer = MPMusicPlayerController.systemMusicPlayer
        
        // Method 1: Check system music player state
        let isSystemPlayerPlaying = musicPlayer.playbackState == .playing && musicPlayer.nowPlayingItem != nil
        
        // Method 2: Check MPNowPlayingInfoCenter with VERY strict criteria
        var isNowPlayingActive = false
        var nowPlayingDetails = "none"
        
        if let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            // Check playback rate - this is the most critical indicator
            let playbackRate = nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] as? Double ?? 0.0
            
            // Get track details for debugging
            let title = nowPlayingInfo[MPMediaItemPropertyTitle] as? String ?? "unknown"
            let artist = nowPlayingInfo[MPMediaItemPropertyArtist] as? String ?? "unknown"
            nowPlayingDetails = "\(title) by \(artist) (rate: \(playbackRate))"
            
            // Check if there's valid track info
            let hasTrackInfo = nowPlayingInfo[MPMediaItemPropertyTitle] != nil ||
                              nowPlayingInfo[MPMediaItemPropertyArtist] != nil
            
            // Much stricter check - must have playback rate exactly 1.0 (actively playing)
            isNowPlayingActive = hasTrackInfo && playbackRate == 1.0
        }
        
        // Method 3: Check our NowPlayingManager
        let hasNowPlayingTrack = nowPlayingManager.currentTrack != nil && 
                                nowPlayingManager.playbackState == .playing
        
        // SUPER CONSERVATIVE: ALL conditions must be true for Apple Music to be considered playing
        let isPlaying = isSystemPlayerPlaying && isNowPlayingActive && hasNowPlayingTrack
        
        // Always log the detailed status for debugging
        print("MusicServiceCoordinator: Apple Music check - System: \(isSystemPlayerPlaying), NowPlaying: \(isNowPlayingActive), Manager: \(hasNowPlayingTrack)")
        print("MusicServiceCoordinator: NowPlaying details: \(nowPlayingDetails)")
        print("MusicServiceCoordinator: Apple Music final decision: \(isPlaying ? "PLAYING" : "NOT PLAYING")")
        
        return isPlaying
    }
    
    private func useAppleMusicTrack() {
        if let nowPlayingTrack = nowPlayingManager.currentTrack {
            if lastTrackTitle != nowPlayingTrack.title {
                print("MusicServiceCoordinator: Using Apple Music track: \(nowPlayingTrack.title)")
            }
            self.currentProvider = .appleMusicStreaming
            self.currentTrack = MusicTrackInfo(
                title: nowPlayingTrack.title,
                artist: nowPlayingTrack.artist,
                album: nowPlayingTrack.album,
                artwork: nowPlayingTrack.artwork,
                provider: .appleMusicStreaming
            )
            self.isPlaying = nowPlayingManager.playbackState == .playing
            self.lastProvider = .appleMusicStreaming
            self.lastTrackTitle = nowPlayingTrack.title
        } else {
            clearCurrentTrack()
        }
    }
    
    private func clearCurrentTrack() {
        if lastProvider != .unknown {
            print("MusicServiceCoordinator: Clearing current track")
        }
        self.currentTrack = nil
        self.currentProvider = .unknown
        self.isPlaying = false
        self.lastProvider = .unknown
        self.lastTrackTitle = nil
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
        spotifyManager.connect()
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