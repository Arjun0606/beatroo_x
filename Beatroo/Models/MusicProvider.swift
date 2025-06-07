import SwiftUI

enum MusicProvider: String, CaseIterable {
    case appleMusicStreaming = "Apple Music"
    case spotify = "Spotify"
    case primeMusic = "Prime Music"
    case youtubeMusic = "YouTube Music"
    case soundCloud = "SoundCloud"
    case pandora = "Pandora"
    case tidal = "Tidal"
    case deezer = "Deezer"
    case unknown = "Unknown"
    
    var color: Color {
        switch self {
        case .appleMusicStreaming:
            return Color(hex: "FB5C74") // Apple Music Pink
        case .spotify:
            return Color(hex: "1DB954") // Spotify Green
        case .primeMusic:
            return Color(hex: "00A8E1") // Amazon Blue
        case .youtubeMusic:
            return Color(hex: "FF0000") // YouTube Red
        case .soundCloud:
            return Color(hex: "FF7700") // SoundCloud Orange
        case .pandora:
            return Color(hex: "3668FF") // Pandora Blue
        case .tidal:
            return Color(hex: "000000") // Tidal Black
        case .deezer:
            return Color(hex: "00C7F2") // Deezer Light Blue
        case .unknown:
            return Color(hex: "B01E68") // Beatroo Pink (default)
        }
    }
    
    static func fromString(_ provider: String) -> MusicProvider {
        let lowercased = provider.lowercased()
        
        if lowercased.contains("apple") {
            return .appleMusicStreaming
        } else if lowercased.contains("spotify") {
            return .spotify
        } else if lowercased.contains("amazon") || lowercased.contains("prime") {
            return .primeMusic
        } else if lowercased.contains("youtube") {
            return .youtubeMusic
        } else if lowercased.contains("soundcloud") {
            return .soundCloud
        } else if lowercased.contains("pandora") {
            return .pandora
        } else if lowercased.contains("tidal") {
            return .tidal
        } else if lowercased.contains("deezer") {
            return .deezer
        } else {
            return .unknown
        }
    }
} 