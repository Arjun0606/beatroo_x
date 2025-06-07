import SwiftUI
import MediaPlayer

struct MusicTrack {
    let title: String
    let artist: String
    let album: String
    let artwork: UIImage?
    let source: String // "Apple Music", "Spotify", etc.
}

class MusicManager: ObservableObject {
    @Published var currentTrack: MusicTrack?
    @Published var isPlaying = false
    
    private let musicPlayer = MPMusicPlayerController.systemMusicPlayer
    
    init() {
        setupNotifications()
        updateNowPlayingInfo()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playbackStateChanged),
            name: .MPMusicPlayerControllerPlaybackStateDidChange,
            object: musicPlayer
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(nowPlayingItemChanged),
            name: .MPMusicPlayerControllerNowPlayingItemDidChange,
            object: musicPlayer
        )
        
        musicPlayer.beginGeneratingPlaybackNotifications()
    }
    
    @objc private func playbackStateChanged() {
        DispatchQueue.main.async {
            self.isPlaying = self.musicPlayer.playbackState == .playing
        }
    }
    
    @objc private func nowPlayingItemChanged() {
        updateNowPlayingInfo()
    }
    
    private func updateNowPlayingInfo() {
        DispatchQueue.main.async {
            if let nowPlayingItem = self.musicPlayer.nowPlayingItem {
                let artwork = nowPlayingItem.artwork?.image(at: CGSize(width: 300, height: 300))
                
                self.currentTrack = MusicTrack(
                    title: nowPlayingItem.title ?? "Unknown Title",
                    artist: nowPlayingItem.artist ?? "Unknown Artist",
                    album: nowPlayingItem.albumTitle ?? "Unknown Album",
                    artwork: artwork,
                    source: "Apple Music"
                )
            } else {
                // For demo purposes, show a sample track
                self.currentTrack = MusicTrack(
                    title: "Body",
                    artist: "Russ Millions x Tion Wayne",
                    album: "Body - Single",
                    artwork: nil,
                    source: "Apple Music"
                )
            }
            
            self.isPlaying = self.musicPlayer.playbackState == .playing
        }
    }
    
    func togglePlayPause() {
        if isPlaying {
            musicPlayer.pause()
        } else {
            musicPlayer.play()
        }
    }
    
    func nextTrack() {
        musicPlayer.skipToNextItem()
    }
    
    func previousTrack() {
        musicPlayer.skipToPreviousItem()
    }
    
    deinit {
        musicPlayer.endGeneratingPlaybackNotifications()
    }
} 