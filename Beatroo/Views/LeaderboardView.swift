import SwiftUI
import FirebaseFirestore

struct LeaderboardView: View {
    @EnvironmentObject var socialMusicManager: SocialMusicManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showRefreshAlert = false
    @State private var showShareableStats = false
    @State private var userStats: UserStats?
    @State private var userRank: Int = 1
    @State private var totalUsers: Int = 1
    
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
                    
                    // Share Stats Button
                    if authManager.currentUser != nil {
                        Button(action: loadUserStats) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.system(size: 16))
                                Text("Share Your Daily Stats")
                                    .font(.system(size: 16, weight: .semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 16)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Leaderboard Content
                if socialMusicManager.isLoading {
                    LoadingView()
                } else if socialMusicManager.leaderboard.isEmpty {
                    EmptyLeaderboardView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(Array(socialMusicManager.leaderboard.enumerated()), id: \.offset) { index, entry in
                                LeaderboardRow(
                                    position: index + 1,
                                    entry: entry
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
        .fullScreenCover(isPresented: $showShareableStats) {
            shareableStatsModal
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
    
    // MARK: - Shareable Stats Functions
    
    private func loadUserStats() {
        guard let userId = authManager.currentUser?.uid,
              let city = locationManager.currentCity else {
            // Create placeholder data with real zeros
            let placeholderStats = UserStats(
                userId: authManager.currentUser?.uid ?? "placeholder",
                totalScore: 0.0,
                lastUpdated: Date(),
                city: locationManager.currentCity ?? "Unknown"
            )
            userStats = placeholderStats
            userRank = 1
            totalUsers = 1
            showShareableStats = true
            return
        }
        
        Task { @MainActor in
            do {
                // Load user stats
                let statsDoc = try await Firestore.firestore()
                    .collection("user_stats")
                    .document(userId)
                    .getDocument()
                
                if let data = statsDoc.data(),
                   let stats = try? Firestore.Decoder().decode(UserStats.self, from: data) {
                    
                    // Load leaderboard to get rank
                    let leaderboardSnapshot = try await Firestore.firestore()
                        .collection("leaderboards")
                        .document(city)
                        .collection("daily")
                        .document(DateFormatter.leaderboardFormatter.string(from: Date()))
                        .getDocument()
                    
                    var rank = 1
                    var total = 1
                    
                    if let leaderboardData = leaderboardSnapshot.data(),
                       let leaderboard = try? Firestore.Decoder().decode(DailyLeaderboard.self, from: leaderboardData) {
                        
                        if let userEntry = leaderboard.entries.first(where: { $0.userId == userId }) {
                            rank = userEntry.rank
                        }
                        total = leaderboard.entries.count
                    }
                    
                    self.userStats = stats
                    self.userRank = rank
                    self.totalUsers = total
                    self.showShareableStats = true
                } else {
                    // No stats found, create with zeros
                    let newStats = UserStats(
                        userId: userId,
                        totalScore: 0.0,
                        lastUpdated: Date(),
                        city: city
                    )
                    self.userStats = newStats
                    self.userRank = 1
                    self.totalUsers = 1
                    self.showShareableStats = true
                }
                
            } catch {
                print("Error loading user stats: \(error)")
                // Show with real zero data on error
                let errorStats = UserStats(
                    userId: userId,
                    totalScore: 0.0,
                    lastUpdated: Date(),
                    city: city
                )
                self.userStats = errorStats
                self.userRank = 1
                self.totalUsers = 1
                self.showShareableStats = true
            }
        }
    }
    
    private var shareableStatsModal: some View {
        ZStack {
            if let stats = userStats, let city = locationManager.currentCity {
                ShareableStatsView(
                    userStats: stats,
                    rank: userRank,
                    totalUsers: totalUsers,
                    city: city,
                    isPresented: $showShareableStats
                )
            }
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
            if let _city = locationManager.currentCity {
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
        .onChange(of: locationManager.currentCity) { oldCity, newCity in
            // **REACTIVE UPDATE**: Force view refresh when location changes
            print("CityLockBanner: City updated to: \(newCity ?? "nil")")
            refreshTrigger.toggle()
        }
        .onChange(of: refreshTrigger) { oldValue, newValue in
            // This forces the view to re-render
        }
    }
    
    private func getCurrentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM dd"
        return formatter.string(from: Date())
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
    let entry: LeaderboardEntry
    
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
                Text("@\(entry.username)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("\(String(format: "%.1f", entry.totalScore)) points")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Score Display (simplified since we don't have individual like/play counts in LeaderboardEntry)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(String(format: "%.1f", entry.totalScore))")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(beatrooPink)
                
                Text("points")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Date Formatter Extension for Leaderboard
extension DateFormatter {
    static let leaderboardFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
} 