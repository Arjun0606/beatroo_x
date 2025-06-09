import Foundation
import CoreLocation

struct NearbyUser: Codable, Identifiable {
    let id: String // user ID
    let username: String
    let displayName: String
    let profilePhotoURL: String?
    let location: GeoPoint
    let currentTrack: CurrentTrack?
    let lastSeen: Date
    let distance: Double? // calculated distance in meters
    
    struct CurrentTrack: Codable {
        let id: String
        let title: String
        let artist: String
        let album: String
        let provider: String // "Spotify", "Apple Music"
        let artworkURL: String?
        let isPlaying: Bool
        let startedAt: Date
    }
}

struct GeoPoint: Codable {
    let latitude: Double
    let longitude: Double
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    init(coordinate: CLLocationCoordinate2D) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
    }
}

struct MusicActivity: Codable, Identifiable {
    let id: String
    let userId: String
    let username: String
    let displayName: String
    let profilePhotoURL: String?
    let trackId: String
    let trackTitle: String
    let trackArtist: String
    let provider: String
    let city: String
    let country: String
    let timestamp: Date
    let likes: [String] // Array of user IDs who liked this
    let plays: [String] // Array of user IDs who played this
    let location: GeoPoint
    
    var likeCount: Int { likes.count }
    var playCount: Int { plays.count }
    var totalScore: Int { likeCount + (playCount * 2) } // Plays worth 2x likes
}

struct MusicLike: Codable, Identifiable {
    let id: String
    let fromUserId: String
    let fromDisplayName: String
    let toUserId: String
    let activityId: String
    let trackTitle: String
    let trackArtist: String
    let timestamp: Date
    let city: String
}

struct MusicPlay: Codable, Identifiable {
    let id: String
    let fromUserId: String
    let fromDisplayName: String
    let toUserId: String
    let activityId: String
    let trackTitle: String
    let trackArtist: String
    let timestamp: Date
    let city: String
}

enum NotificationType: String, Codable {
    case musicLike = "music_like"
    case musicPlay = "music_play"
}

struct MusicNotification: Codable, Identifiable {
    let id: String
    let toUserId: String
    let fromUserId: String
    let fromDisplayName: String
    let type: NotificationType
    let trackTitle: String
    let trackArtist: String
    let message: String
    let timestamp: Date
    let isRead: Bool
    
    static func likeMessage(fromName: String, track: String) -> String {
        return "\(fromName) vibed with your taste! 🎵"
    }
    
    static func playMessage(fromName: String, track: String) -> String {
        return "\(fromName) is jamming to your vibe! 🎧"
    }
} 