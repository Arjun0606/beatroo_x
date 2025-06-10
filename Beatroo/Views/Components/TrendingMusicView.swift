import SwiftUI

struct TrendingMusicView: View {
    @ObservedObject var trendingManager: TrendingMusicManager
    let city: String
    
    private let beatrooPink = Color(hex: "B01E68")
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔥 Trending in \(city)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Most vibed tracks today")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                if trendingManager.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: beatrooPink))
                        .scaleEffect(0.8)
                } else {
                    Button(action: {
                        trendingManager.refreshTrendingMusic()
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16))
                            .foregroundColor(beatrooPink)
                    }
                }
            }
            
            // Trending Tracks List
            if trendingManager.trendingTracks.isEmpty && !trendingManager.isLoading {
                TrendingEmptyStateView()
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(Array(trendingManager.trendingTracks.enumerated()), id: \.element.id) { index, track in
                        TrendingTrackRowView(track: track, rank: index + 1)
                    }
                }
            }
            
            if let errorMessage = trendingManager.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 20)
        .onAppear {
            trendingManager.loadTrendingMusic(for: city)
        }
        .onChange(of: city) { newCity in
            trendingManager.loadTrendingMusic(for: newCity)
        }
    }
}

struct TrendingTrackRowView: View {
    let track: TrendingTrack
    let rank: Int
    
    private let beatrooPink = Color(hex: "B01E68")
    
    var body: some View {
        HStack(spacing: 12) {
            // Rank with gradient background
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(rankGradient)
                    .frame(width: 30, height: 30)
                
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // Track Info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(track.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    if rank <= 3 {
                        Text(track.trendingIcon)
                            .font(.system(size: 14))
                    }
                }
                
                Text(track.artist)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 2) {
                Text(track.scoreDisplay)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(beatrooPink)
                
                HStack(spacing: 8) {
                    if track.likeCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "heart.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.red)
                            Text("\(track.likeCount)")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if track.playCount > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                            Text("\(track.playCount)")
                                .font(.system(size: 10))
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var rankGradient: LinearGradient {
        switch rank {
        case 1:
            return LinearGradient(colors: [Color.orange, Color.red], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 2:
            return LinearGradient(colors: [Color.yellow, Color.orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        case 3:
            return LinearGradient(colors: [Color.blue, Color.purple], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [beatrooPink.opacity(0.8), beatrooPink], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

struct TrendingEmptyStateView: View {
    private let beatrooPink = Color(hex: "B01E68")
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(beatrooPink.opacity(0.2))
                    .frame(width: 60, height: 60)
                
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 24))
                    .foregroundColor(beatrooPink)
            }
            
            VStack(spacing: 4) {
                Text("No Trending Music Yet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("Be the first to like or play music in your city!")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Preview
struct TrendingMusicView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TrendingMusicView(trendingManager: TrendingMusicManager(), city: "San Francisco")
        }
    }
} 