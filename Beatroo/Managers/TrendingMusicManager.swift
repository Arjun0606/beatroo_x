import Foundation
import Firebase
import FirebaseFirestore
import SwiftUI

class TrendingMusicManager: ObservableObject {
    @Published var trendingTracks: [TrendingTrack] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var currentCity: String?
    
    // MARK: - Public Methods
    
    func loadTrendingMusic(for city: String) {
        guard city != currentCity else { return } // Don't reload same city
        
        currentCity = city
        isLoading = true
        errorMessage = nil
        
        Task {
            await fetchTrendingMusic(for: city)
        }
    }
    
    func refreshTrendingMusic() {
        guard let city = currentCity else { return }
        Task {
            await fetchTrendingMusic(for: city)
        }
    }
    
    // MARK: - Private Methods
    
    private func fetchTrendingMusic(for city: String) async {
        let today = DateFormatter.dayFormatter.string(from: Date())
        
        do {
            let snapshot = try await db.collection("trending_music")
                .document(city)
                .collection("daily")
                .document(today)
                .getDocument()
            
            if let data = snapshot.data(),
               let trendsData = try? Firestore.Decoder().decode(DailyTrendingData.self, from: data) {
                
                DispatchQueue.main.async {
                    self.trendingTracks = trendsData.tracks.prefix(10).map { $0 } // Top 10
                    self.isLoading = false
                }
            } else {
                // No trending data for today, generate from interactions
                await generateTrendingData(for: city, date: today)
            }
            
        } catch {
            print("Error fetching trending music: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to load trending music"
                self.isLoading = false
            }
        }
    }
    
    private func generateTrendingData(for city: String, date: String) async {
        print("Generating trending data for \(city)")
        
        do {
            // Get all music interactions for today in this city
            let startOfDay = Calendar.current.startOfDay(for: Date())
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? Date()
            
            // Fetch likes
            let likesSnapshot = try await db.collection("music_likes")
                .whereField("city", isEqualTo: city)
                .whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("timestamp", isLessThan: Timestamp(date: endOfDay))
                .getDocuments()
            
            // Fetch plays  
            let playsSnapshot = try await db.collection("music_plays")
                .whereField("city", isEqualTo: city)
                .whereField("timestamp", isGreaterThanOrEqualTo: Timestamp(date: startOfDay))
                .whereField("timestamp", isLessThan: Timestamp(date: endOfDay))
                .getDocuments()
            
            // Aggregate track data
            var trackStats: [String: TrackStats] = [:]
            
            // Process likes (1 point each)
            for doc in likesSnapshot.documents {
                if let like = try? Firestore.Decoder().decode(MusicLike.self, from: doc.data()) {
                    let key = "\(like.trackTitle)|\(like.trackArtist)"
                    if trackStats[key] == nil {
                        trackStats[key] = TrackStats(title: like.trackTitle, artist: like.trackArtist, city: city)
                    }
                    trackStats[key]?.likeCount += 1
                    trackStats[key]?.totalInteractions += 1
                }
            }
            
            // Process plays (2 points each)
            for doc in playsSnapshot.documents {
                if let play = try? Firestore.Decoder().decode(MusicPlay.self, from: doc.data()) {
                    let key = "\(play.trackTitle)|\(play.trackArtist)"
                    if trackStats[key] == nil {
                        trackStats[key] = TrackStats(title: play.trackTitle, artist: play.trackArtist, city: city)
                    }
                    trackStats[key]?.playCount += 1
                    trackStats[key]?.totalInteractions += 2 // Plays worth 2 points
                }
            }
            
            // Convert to trending tracks and sort
            let trendingTracks = trackStats.values
                .filter { $0.totalInteractions > 0 }
                .sorted { $0.totalInteractions > $1.totalInteractions }
                .enumerated()
                .map { index, stats in
                    TrendingTrack(
                        id: "\(stats.title)_\(stats.artist)_\(city)".replacingOccurrences(of: " ", with: "_"),
                        title: stats.title,
                        artist: stats.artist,
                        album: "", // Album info not available from likes/plays data
                        artworkURL: nil, // Artwork URL not available from likes/plays data
                        city: city,
                        totalInteractions: stats.totalInteractions,
                        likeCount: stats.likeCount,
                        playCount: stats.playCount,
                        lastUpdated: Date(),
                        rank: index + 1
                    )
                }
            
            // Save trending data
            let trendingData = DailyTrendingData(
                city: city,
                date: date,
                tracks: Array(trendingTracks.prefix(20)), // Top 20
                lastUpdated: Date()
            )
            
            try await db.collection("trending_music")
                .document(city)
                .collection("daily")
                .document(date)
                .setData(try Firestore.Encoder().encode(trendingData))
            
            // Update UI
            DispatchQueue.main.async {
                self.trendingTracks = Array(trendingTracks.prefix(10)) // Show top 10
                self.isLoading = false
            }
            
        } catch {
            print("Error generating trending data: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to generate trending music"
                self.isLoading = false
            }
        }
    }
}

// MARK: - Helper Structures

private struct TrackStats {
    let title: String
    let artist: String
    let city: String
    var likeCount: Int = 0
    var playCount: Int = 0
    var totalInteractions: Int = 0
}

// MARK: - Date Formatter Extension

private extension DateFormatter {
    static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
} 