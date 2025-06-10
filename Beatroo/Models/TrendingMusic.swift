import Foundation
import Firebase
import FirebaseFirestore

struct TrendingTrack: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let album: String
    let artworkURL: String?
    let city: String
    let totalInteractions: Int // likes + plays
    let likeCount: Int
    let playCount: Int
    let lastUpdated: Date
    let rank: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case artist
        case album
        case artworkURL = "artwork_url"
        case city
        case totalInteractions = "total_interactions"
        case likeCount = "like_count"
        case playCount = "play_count"
        case lastUpdated = "last_updated"
        case rank
    }
    
    var scoreDisplay: String {
        return "\(totalInteractions) vibes"
    }
    
    var trendingIcon: String {
        switch rank {
        case 1: return "🔥"
        case 2: return "⚡"
        case 3: return "💎"
        default: return "🎵"
        }
    }
}

struct DailyTrendingData: Codable {
    let city: String
    let date: String // YYYY-MM-DD format
    let tracks: [TrendingTrack]
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case city
        case date
        case tracks
        case lastUpdated = "last_updated"
    }
} 