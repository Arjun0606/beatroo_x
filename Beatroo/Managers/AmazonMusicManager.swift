import SwiftUI
import MediaPlayer

class AmazonMusicManager: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTrack: AmazonMusicTrack?
    
    init() {
        print("AmazonMusicManager: Initializing")
        setupObservers()
        checkAmazonMusicInstalled()
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
            // Check if the source is likely Amazon Music
            if isAmazonMusicPlaying(nowPlaying: nowPlaying) {
                updateTrackInfo(from: nowPlaying)
            }
        }
    }
    
    private func isAmazonMusicPlaying(nowPlaying: [String: Any]) -> Bool {
        // Try to determine if Amazon Music is the source
        
        // Check if bundle identifier is available and contains Amazon
        if let bundleID = nowPlaying["bundleIdentifier"] as? String,
           bundleID.lowercased().contains("amazon") {
            return true
        }
        
        // Check if app name is available
        if let sourceInfo = nowPlaying["sourceInfo"] as? [String: Any],
           let appName = sourceInfo["name"] as? String,
           appName.lowercased().contains("amazon") || appName.lowercased().contains("prime") {
            return true
        }
        
        // Check if Amazon Music is installed and likely to be playing
        if checkAmazonMusicInstalled() && isAnyMusicPlaying() {
            // Additional logic could check if known Apple Music or Spotify tracks
            // are not playing, making it more likely this is Amazon Music
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
            self.currentTrack = AmazonMusicTrack(
                title: title,
                artist: artist,
                album: album,
                artwork: artwork
            )
            self.isPlaying = true
        }
    }
    
    func checkAmazonMusicInstalled() -> Bool {
        // Check if Amazon Music app is installed
        guard let amazonURL = URL(string: "amazonmusic:") else { return false }
        return UIApplication.shared.canOpenURL(amazonURL)
    }
    
    private func isAnyMusicPlaying() -> Bool {
        return AVAudioSession.sharedInstance().secondaryAudioShouldBeSilencedHint
    }
    
    func openAmazonMusic() {
        if let url = URL(string: "amazonmusic:") {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        } else {
            // Fallback to app store if not installed
            if let appStoreURL = URL(string: "https://apps.apple.com/app/amazon-music/id510855668") {
                UIApplication.shared.open(appStoreURL, options: [:], completionHandler: nil)
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

struct AmazonMusicTrack {
    let title: String
    let artist: String
    let album: String
    let artwork: UIImage?
} 