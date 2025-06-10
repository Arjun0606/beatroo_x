import SwiftUI

struct LeaderboardView: View {
    @EnvironmentObject var socialMusicManager: SocialMusicManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var showRefreshAlert = false
    
    private let beatrooPink = Color(hex: "B01E68")
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header with City Lock
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Leaderboard")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            Task {
                                await socialMusicManager.loadLeaderboard()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20))
                                .foregroundColor(beatrooPink)
                        }
                    }
                    
                    // City Lock Banner
                    CityLockBanner()
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Info Banner
                InfoBannerView()
                
                // Leaderboard Content
                if socialMusicManager.isLoading {
                    LoadingView()
                } else if socialMusicManager.leaderboard.isEmpty {
                    EmptyLeaderboardView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(socialMusicManager.leaderboard.enumerated()), id: \.element.id) { index, activity in
                                LeaderboardRow(
                                    position: index + 1,
                                    activity: activity
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    }
                }
                
                Spacer()
            }
        }
        .onAppear {
            Task {
                await socialMusicManager.loadLeaderboard()
            }
        }
        .alert("Daily Reset", isPresented: $showRefreshAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Leaderboard resets every day at midnight. Keep sharing great music to climb the ranks!")
        }
    }
}

struct CityLockBanner: View {
    @EnvironmentObject var locationManager: LocationManager
    @State private var refreshTrigger = false
    private let beatrooPink = Color(hex: "B01E68")
    
    var body: some View {
        HStack(spacing: 12) {
            // Location Icon
            Image(systemName: "location.fill")
                .font(.system(size: 16))
                .foregroundColor(beatrooPink)
            
            VStack(alignment: .leading, spacing: 2) {
                if let city = locationManager.currentCity {
                    HStack(spacing: 4) {
                        let locationText = if let country = locationManager.currentCountry {
                            "📍 \(city), \(country)"
                        } else {
                            "📍 \(city)"
                        }
                        
                        Text(locationText)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundColor(beatrooPink.opacity(0.7))
                    }
                    
                    Text("Geo-locked to your current location")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                } else {
                    HStack(spacing: 4) {
                        Text("📍 Locating...")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.gray)
                        
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.7)
                    }
                    
                    Text("Getting your location for city leaderboard")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // City Stats Badge
            if let city = locationManager.currentCity {
                VStack(spacing: 2) {
                    Text("TODAY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(beatrooPink)
                    
                    Text(getCurrentDateString())
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(beatrooPink.opacity(0.2))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(beatrooPink.opacity(0.3), lineWidth: 1)
                )
        )
        .onAppear {
            // Auto-request location permission when banner appears
            if locationManager.authorizationStatus == .notDetermined {
                locationManager.requestLocationPermission()
            }
            
            // **FORCE REFRESH**: Trigger a manual refresh to ensure UI updates
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                refreshTrigger.toggle()
            }
        }
        .onChange(of: locationManager.currentCity) { newCity in
            // **REACTIVE UPDATE**: Force view refresh when location changes
            print("CityLockBanner: City updated to: \(newCity ?? "nil")")
            refreshTrigger.toggle()
        }
        .onChange(of: refreshTrigger) { _ in
            // This forces the view to re-render
        }
    }
    
    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: Date())
    }
}

struct InfoBannerView: View {
    private let beatrooPink = Color(hex: "B01E68")
    
    var body: some View {
        VStack(spacing: 12) {
            // Title
            Text("💎 Scoring System")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            
            // Getting points (receiving)
            VStack(spacing: 6) {
                Text("When Others Interact With Your Vibes:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                                .font(.system(size: 12))
                            Text("1 pt")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text("per like")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                    
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 12))
                            Text("2 pts")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        Text("per play")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Giving points (engaging)
            VStack(spacing: 6) {
                Text("When You Discover Others' Music:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.pink)
                                .font(.system(size: 10))
                            Text("+0.25")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.pink)
                        }
                        Text("for liking")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                    
                    VStack(spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .foregroundColor(.cyan)
                                .font(.system(size: 10))
                            Text("+0.5")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.cyan)
                        }
                        Text("for playing")
                            .font(.system(size: 9))
                            .foregroundColor(.gray)
                    }
                }
            }
            
            // Daily reset
            HStack(spacing: 8) {
                Text("🕛")
                    .font(.system(size: 14))
                Text("Resets daily")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }
}

struct LoadingView: View {
    private let beatrooPink = Color(hex: "B01E68")
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: beatrooPink))
                .scaleEffect(1.2)
            
            Text("Loading leaderboard...")
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Spacer()
        }
    }
}

struct EmptyLeaderboardView: View {
    private let beatrooPink = Color(hex: "B01E68")
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "trophy.fill")
                .font(.system(size: 60))
                .foregroundColor(beatrooPink.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("No Scores Yet")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Be the first to share your music taste today! Play some music and let others discover your vibe.")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
}

struct LeaderboardRow: View {
    let position: Int
    let activity: MusicActivity
    
    private let beatrooPink = Color(hex: "B01E68")
    
    private var rankColor: Color {
        switch position {
        case 1: return .yellow
        case 2: return Color.gray
        case 3: return Color.orange
        default: return beatrooPink
        }
    }
    
    private var rankIcon: String {
        switch position {
        case 1: return "crown.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return "\(position).circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Rank
            VStack(spacing: 4) {
                Image(systemName: rankIcon)
                    .font(.system(size: position <= 3 ? 24 : 20))
                    .foregroundColor(rankColor)
                
                if position > 3 {
                    Text("#\(position)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(rankColor)
                }
            }
            .frame(width: 40)
            
            // User Info
            VStack(alignment: .leading, spacing: 4) {
                Text("@\(activity.username)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("\(activity.trackTitle)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(beatrooPink)
                    .lineLimit(1)
                
                Text("by \(activity.trackArtist)")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Stats
            VStack(alignment: .trailing, spacing: 8) {
                // Total Score
                VStack(spacing: 2) {
                    Text("\(activity.totalScore)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(rankColor)
                    Text("points")
                        .font(.system(size: 10))
                        .foregroundColor(.gray)
                }
                
                // Breakdown
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 10))
                        Text("\(activity.likeCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "play.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 10))
                        Text("\(activity.playCount)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .padding()
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.gray.opacity(position <= 3 ? 0.2 : 0.1),
                    Color.gray.opacity(position <= 3 ? 0.1 : 0.05)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    position <= 3 ? rankColor.opacity(0.3) : Color.clear,
                    lineWidth: position <= 3 ? 1 : 0
                )
        )
    }
} 