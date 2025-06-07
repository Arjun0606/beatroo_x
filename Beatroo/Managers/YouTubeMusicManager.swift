import SwiftUI
import MediaPlayer

class YouTubeMusicManager: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTrack: YouTubeMusicTrack?
    
    init() {
        print("YouTubeMusicManager: Initializing")
        setupObservers()
        checkYouTubeMusicInstalled()
    }
    
    private func setupObservers() {
        // Observe for now playing info changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingInfoChanged),
            name: NSNotification.Name("MPNowPlayingInfoDidChange"),
            object: nil
        )
    }
    
    @objc private func nowPlayingInfoChanged() {
        if let nowPlaying = MPNowPlayingInfoCenter.default().nowPlayingInfo {
            // Check if the source is likely YouTube Music
            if isYouTubeMusicPlaying(nowPlaying: nowPlaying) {
                updateTrackInfo(from: nowPlaying)
            }
        }
    }
    
    private func isYouTubeMusicPlaying(nowPlaying: [String: Any]) -> Bool {
        // Try to determine if YouTube Music is the source
        
        // Check if bundle identifier is available and contains YouTube
        if let bundleID = nowPlaying["bundleIdentifier"] as? String,
           bundleID.lowercased().contains("youtube") {
            return true
        }
        
        // Check if app name is available
        if let sourceInfo = nowPlaying["sourceInfo"] as? [String: Any],
           let appName = sourceInfo["name"] as? String,
           appName.lowercased().contains("youtube") {
            return true
        }
        
        // Check if YouTube Music is installed and likely to be playing
        if checkYouTubeMusicInstalled() && isAnyMusicPlaying() {
            // Additional logic could check if known Apple Music or Spotify tracks
            // are not playing, making it more likely this is YouTube Music
            return true
        }
        
        return false
    }
    
    private func updateTrackInfo(from nowPlaying: [String: Any]) {
        let title = nowPlaying[MPMediaItemPropertyTitle] as? String ?? "Unknown Title"
        let artist = nowPlaying[MPMediaItemPropertyArtist] as? String ?? "Unknown Artist"
        let album = nowPlaying[MPMediaItemPropertyAlbumTitle] as? String ?? "Unknown Album"
        var artwork: UIImage? = nil
        
        if let artworkData = nowPlaying[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
            artwork = artworkData.image(at: CGSize(width: 300, height: 300))
        }
        
        DispatchQueue.main.async {
            self.currentTrack = YouTubeMusicTrack(
                title: title,
                artist: artist,
                album: album,
                artwork: artwork
            )
            self.isPlaying = true
        }
    }
    
    func checkYouTubeMusicInstalled() -> Bool {
        // Check if YouTube Music app is installed
        guard let youtubeURL = URL(string: "youtubemusic:") else { return false }
        return UIApplication.shared.canOpenURL(youtubeURL)
    }
    
    private func isAnyMusicPlaying() -> Bool {
        return AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
    }
    
    func openYouTubeMusic() {
        if let url = URL(string: "youtubemusic:") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            // Fallback to app store if not installed
            if let appStoreURL = URL(string: "https://apps.apple.com/app/youtube-music/id1017492454") {
                UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct YouTubeMusicTrack {
    let title: String
    let artist: String
    let album: String
    let artwork: UIImage?
} 