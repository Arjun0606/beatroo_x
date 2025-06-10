import SwiftUI
import MediaPlayer
import AVFoundation

class NowPlayingManager: ObservableObject {
    @Published var currentTrack: NowPlayingTrack?
    @Published var playbackState: PlaybackState = .stopped
    
    private let systemMusicPlayer = MPMusicPlayerController.systemMusicPlayer
    private var playbackObserver: NSObjectProtocol?
    private var routeChangeObserver: NSObjectProtocol?
    private var stateChangeObserver: NSObjectProtocol?
    private var updateTimer: Timer?
    
    // Reference to Spotify manager for proper detection
    private var spotifyManager: SpotifyManager?
    
    // Added dictionary to store app bundle identifiers
    private let knownMusicApps: [String: MusicProvider] = [
        "com.spotify.client": .spotify,
        "com.apple.Music": .appleMusicStreaming,
        "com.google.ios.youtubemusic": .youtubeMusic,
        "com.amazon.AmazonMusic": .primeMusic,
        "com.soundcloud.TouchApp": .soundCloud,
        "com.pandora": .pandora,
        "com.tidal.tidal": .tidal,
        "com.deezer.Deezer": .deezer
    ]
    
    init() {
        print("NowPlayingManager: Initializing")
        systemMusicPlayer.beginGeneratingPlaybackNotifications()
        setupNotifications()
        checkAuthorizationAndUpdateNowPlaying()
        setupAudioSession()
        startPeriodicUpdates()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session:", error)
        }
    }
    
    func startObservingPlayback() {
        print("NowPlayingManager: Starting playback observation")
        systemMusicPlayer.beginGeneratingPlaybackNotifications()
        updateNowPlaying()
        updatePlaybackState()
    }
    
    private func setupNotifications() {
        print("NowPlayingManager: Setting up notifications")
        
        // Remove any existing observers
        [playbackObserver, routeChangeObserver, stateChangeObserver].forEach { observer in
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        
        // Observe playback state changes
        playbackObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: systemMusicPlayer,
            queue: .main
        ) { [weak self] _ in
            print("NowPlayingManager: Now playing item changed")
            self?.updateNowPlaying()
        }
        
        // Observe audio route changes
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("NowPlayingManager: Audio route changed")
            self?.updateNowPlaying()
        }
        
        // Add observer for MPNowPlayingInfoCenter changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingInfoChanged),
            name: NSNotification.Name("MPNowPlayingInfoDidChange"),
            object: nil
        )
        
        // Observe playback state changes
        stateChangeObserver = NotificationCenter.default.addObserver(
            forName: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: systemMusicPlayer,
            queue: .main
        ) { [weak self] _ in
            print("NowPlayingManager: Playback state changed")
            self?.updatePlaybackState()
        }
    }
    
    @objc private func nowPlayingInfoChanged() {
        print("NowPlayingManager: Now playing info changed")
        updateNowPlaying()
    }
    
    private func updatePlaybackState() {
        DispatchQueue.main.async {
            switch self.systemMusicPlayer.playbackState {
            case .playing:
                self.playbackState = .playing
            case .paused:
                self.playbackState = .paused
            case .stopped:
                self.playbackState = .stopped
            case .interrupted:
                self.playbackState = .interrupted
            case .seekingForward:
                self.playbackState = .seekingForward
            case .seekingBackward:
                self.playbackState = .seekingBackward
            @unknown default:
                self.playbackState = .stopped
            }
        }
    }
    
    func togglePlayback() {
        switch playbackState {
        case .playing:
            systemMusicPlayer.pause()
        case .paused, .stopped:
            systemMusicPlayer.play()
        default:
            break
        }
    }
    
    func skipToNextTrack() {
        systemMusicPlayer.skipToNextItem()
    }
    
    func skipToPreviousTrack() {
        systemMusicPlayer.skipToPreviousItem()
    }
    
    private func checkAuthorizationAndUpdateNowPlaying() {
        let authStatus = MPMediaLibrary.authorizationStatus()
        print("NowPlayingManager: Media Library Authorization Status:", authStatus.rawValue)
        
        switch authStatus {
        case .authorized:
            print("NowPlayingManager: Already authorized")
            updateNowPlaying()
        case .notDetermined:
            print("NowPlayingManager: Requesting authorization")
            MPMediaLibrary.requestAuthorization { [weak self] status in
                print("NowPlayingManager: Authorization status after request:", status.rawValue)
                if status == .authorized {
                    DispatchQueue.main.async {
                        self?.updateNowPlaying()
                    }
                }
            }
        default:
            print("NowPlayingManager: Not authorized")
        }
    }
    
    // Simple and accurate detection of music provider
    private func detectMusicProvider(nowPlaying: [String: Any]? = nil) -> MusicProvider {
        // For Apple Music, since we're detecting it through the system music player,
        // we know it's Apple Music. The coordinator will handle prioritization.
        return .appleMusicStreaming
    }
    

    
    private func updateNowPlaying() {
        print("NowPlayingManager: Updating now playing info")
        
        // First try getting info from system music player
        if let nowPlayingItem = systemMusicPlayer.nowPlayingItem {
            print("NowPlayingManager: Found now playing item from system player")
            let title = nowPlayingItem.title ?? "Unknown Title"
            let artist = nowPlayingItem.artist ?? "Unknown Artist"
            let album = nowPlayingItem.albumTitle ?? "Unknown Album"
            var artwork: UIImage? = nil
            
            if let artworkItem = nowPlayingItem.artwork {
                artwork = artworkItem.image(at: CGSize(width: 300, height: 300))
            }
            
            let provider = detectMusicProvider()
            
            DispatchQueue.main.async {
                self.currentTrack = NowPlayingTrack(
                    title: title,
                    artist: artist,
                    album: album,
                    artwork: artwork,
                    musicProvider: provider
                )
            }
            return
        }
        
        // Fallback to now playing info center
        if let nowPlaying = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            print("NowPlayingManager: Found now playing info from info center")
            let title = nowPlaying[MPMediaItemPropertyTitle] as? String ?? "Unknown Title"
            let artist = nowPlaying[MPMediaItemPropertyArtist] as? String ?? "Unknown Artist"
            let album = nowPlaying[MPMediaItemPropertyAlbumTitle] as? String ?? "Unknown Album"
            var artwork: UIImage? = nil
            
            if let artworkData = nowPlaying[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
                artwork = artworkData.image(at: CGSize(width: 300, height: 300))
            }
            
            let provider = detectMusicProvider(nowPlaying: nowPlaying)
            
            DispatchQueue.main.async {
                self.currentTrack = NowPlayingTrack(
                    title: title,
                    artist: artist,
                    album: album,
                    artwork: artwork,
                    musicProvider: provider
                )
            }
        } else {
            print("NowPlayingManager: No now playing info found")
            DispatchQueue.main.async {
                self.currentTrack = nil
            }
        }
        
        updatePlaybackState()
    }
    
    func setSpotifyManager(_ manager: SpotifyManager) {
        self.spotifyManager = manager
    }
    
    private func startPeriodicUpdates() {
        // Check for Apple Music updates every 2 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateNowPlaying()
        }
    }
    
    deinit {
        print("NowPlayingManager: Deinitializing")
        updateTimer?.invalidate()
        [playbackObserver, routeChangeObserver, stateChangeObserver].forEach { observer in
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        systemMusicPlayer.endGeneratingPlaybackNotifications()
    }
}

struct NowPlayingTrack {
    let title: String
    let artist: String
    let album: String
    let artwork: UIImage?
    let musicProvider: MusicProvider
    
    var platform: String {
        return musicProvider.rawValue
    }
}

enum PlaybackState {
    case playing
    case paused
    case stopped
    case interrupted
    case seekingForward
    case seekingBackward
    
    var systemImageName: String {
        switch self {
        case .playing:
            return "pause.fill"
        case .paused, .stopped, .interrupted:
            return "play.fill"
        case .seekingForward:
            return "forward.fill"
        case .seekingBackward:
            return "backward.fill"
        }
    }
} 