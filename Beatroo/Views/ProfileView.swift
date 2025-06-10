import SwiftUI
import Firebase
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var musicCoordinator: MusicServiceCoordinator
    @EnvironmentObject var locationManager: LocationManager
    @State private var showSignOutAlert = false
    @State private var showDeleteAlert = false
    @State private var showEditProfile = false
    @State private var isConnectingSpotify = false
    @State private var isDeletingAccount = false
    @State private var showScoringInfo = false
    @State private var userStats: UserStats?
    @State private var userRank: Int = 0
    @State private var totalUsers: Int = 0
    
    private let beatrooPink = Color(hex: "B01E68") // Consistent Beatroo pink color
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        HStack {
                            Text("Profile")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Button(action: { showSignOutAlert = true }) {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 20))
                                    .foregroundColor(beatrooPink)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        
                        if let user = authManager.currentUser {
                            // Profile Photo
                            VStack(spacing: 20) {
                                if let photoURL = user.photoURL,
                                   let url = URL(string: photoURL) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: beatrooPink))
                                    }
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(beatrooPink, lineWidth: 3)
                                    )
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 120, height: 120)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 50))
                                                .foregroundColor(.gray)
                                        )
                                }
                                
                                // Display Name & Username
                                VStack(spacing: 8) {
                                    Text(user.displayName)
                                        .font(.system(size: 28, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("@\(user.username)")
                                        .font(.system(size: 18))
                                        .foregroundColor(beatrooPink)
                                }
                            }
                            
                            // Scoring System Section
                            VStack(alignment: .leading, spacing: 15) {
                                HStack {
                                    Text("💎 Scoring System")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Button(action: { showScoringInfo = true }) {
                                        Image(systemName: "info.circle")
                                            .font(.system(size: 20))
                                            .foregroundColor(beatrooPink)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            
                            // Profile Info Cards
                            VStack(spacing: 15) {
                                ProfileInfoCard(
                                    icon: "envelope.fill",
                                    title: "Email",
                                    value: user.email,
                                    iconColor: beatrooPink
                                )
                                
                                if let age = user.currentAge {
                                    ProfileInfoCard(
                                        icon: "calendar",
                                        title: "Age",
                                        value: "\(age) years old",
                                        iconColor: beatrooPink
                                    )
                                }
                                
                                ProfileInfoCard(
                                    icon: "person.fill",
                                    title: "Gender",
                                    value: user.gender == .custom ? (user.customGender ?? user.gender.displayName) : user.gender.displayName,
                                    iconColor: beatrooPink
                                )
                                
                                ProfileInfoCard(
                                    icon: "clock.fill",
                                    title: "Member Since",
                                    value: formatDate(user.createdAt),
                                    iconColor: beatrooPink
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            
                            // Music Services Section
                            musicServicesSection
                            
                            // Account Management Section
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Account Management")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                
                                VStack(spacing: 15) {
                                    // Edit Profile Button
                                    Button(action: { showEditProfile = true }) {
                                        HStack(spacing: 15) {
                                            Image(systemName: "pencil.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(beatrooPink)
                                                .frame(width: 30)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Edit Profile")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.white)
                                                
                                                Text("Update your username and profile picture")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.gray)
                                                .font(.system(size: 14))
                                        }
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(12)
                                    }
                                    
                                    // Delete Account Button
                                    Button(action: { showDeleteAlert = true }) {
                                        HStack(spacing: 15) {
                                            Image(systemName: "trash.circle.fill")
                                                .font(.system(size: 20))
                                                .foregroundColor(.red)
                                                .frame(width: 30)
                                            
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Delete Account")
                                                    .font(.system(size: 16, weight: .medium))
                                                    .foregroundColor(.red)
                                                
                                                Text("Permanently delete your account and data")
                                                    .font(.system(size: 14))
                                                    .foregroundColor(.gray)
                                            }
                                            
                                            Spacer()
                                            
                                            if isDeletingAccount {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                                    .scaleEffect(0.8)
                                            } else {
                                                Image(systemName: "chevron.right")
                                                    .foregroundColor(.gray)
                                                    .font(.system(size: 14))
                                            }
                                        }
                                        .padding()
                                        .background(Color.gray.opacity(0.1))
                                        .cornerRadius(12)
                                    }
                                    .disabled(isDeletingAccount)
                                }
                                .padding(.horizontal, 20)
                            }
                            .padding(.top, 30)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            ProfileEditView()
                .environmentObject(authManager)
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .alert("Delete Account", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("This action cannot be undone. All your data will be permanently deleted.")
        }
        .sheet(isPresented: $showScoringInfo) {
            ScoringInfoSheet(isPresented: $showScoringInfo)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "Connected":
            return .green
        case "Spotify app not running", "Reconnecting...", "Ready to reconnect":
            return .orange
        case "Spotify app not installed":
            return .red
        case "Ready to connect":
            return .gray
        default:
            return .yellow
        }
    }
    
    private func connectSpotify() {
        guard !isConnectingSpotify else { return }
        
        isConnectingSpotify = true
        
        // Use the standard connection method for now
        musicCoordinator.connectToSpotify()
        
        // Monitor connection status with longer timeout
        var checkCount = 0
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            checkCount += 1
            
            // Check if connected
            if musicCoordinator.spotifyManager.isConnected {
                isConnectingSpotify = false
                timer.invalidate()
            }
            // Check if authorization started (user redirected to Spotify)
            else if musicCoordinator.spotifyManager.connectionStatus.contains("Authorizing") {
                // Keep spinner active but stop after reasonable time
                if checkCount > 20 { // 10 seconds
                    isConnectingSpotify = false
                    timer.invalidate()
                }
            }
            // Stop after 15 seconds regardless
            else if checkCount > 30 {
                isConnectingSpotify = false
                timer.invalidate()
            }
        }
    }
    
    private func deleteAccount() {
        guard !isDeletingAccount else { return }
        
        isDeletingAccount = true
        
        Task {
            do {
                try await authManager.deleteAccount()
                // No need to update UI here as the user will be signed out automatically
            } catch {
                await MainActor.run {
                    isDeletingAccount = false
                    // You could show an error alert here if needed
                    print("Error deleting account: \(error)")
                }
            }
        }
    }
    
    private var musicServicesSection: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Music Services")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)
            
            VStack(spacing: 15) {
                spotifyServiceRow
                appleMusicServiceRow
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 30)
    }
    
    private var spotifyServiceRow: some View {
        HStack(spacing: 15) {
            Image(systemName: "music.note.list")
                .font(.system(size: 20))
                .foregroundColor(.green)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Spotify")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text(musicCoordinator.spotifyManager.isConnected ? "Connected" : "Not connected")
                    .font(.system(size: 14))
                    .foregroundColor(musicCoordinator.spotifyManager.isConnected ? .green : .gray)
            }
            
            Spacer()
            
            spotifyActionButton
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
                                    
    private var appleMusicServiceRow: some View {
        HStack(spacing: 15) {
            Image(systemName: "music.note")
                .font(.system(size: 20))
                .foregroundColor(beatrooPink)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Apple Music")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Always available")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 20))
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var spotifyActionButton: some View {
        if musicCoordinator.spotifyManager.isConnected {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 20))
        } else if musicCoordinator.spotifyManager.hasSpotifyCredentials {
            // Has credentials - show reconnect button
            Button(action: connectSpotify) {
                if isConnectingSpotify {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Reconnect")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .cornerRadius(20)
                }
            }
            .disabled(isConnectingSpotify)
        } else {
            // No credentials - show connect button
            Button(action: connectSpotify) {
                if isConnectingSpotify {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Connect")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.green)
                        .cornerRadius(20)
                }
            }
            .disabled(isConnectingSpotify)
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
            }
        }
    }
}

// MARK: - Scoring Info Sheet

struct ScoringInfoSheet: View {
    @Binding var isPresented: Bool
    private let beatrooPink = Color(hex: "B01E68")
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Text("💎")
                                .font(.system(size: 60))
                            
                            Text("Scoring System")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("How points are earned in Beatroo")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 20)
                        
                        // Getting points (receiving)
                        VStack(spacing: 16) {
                            Text("When Others Interact With Your Vibes:")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(spacing: 12) {
                                HStack(spacing: 16) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "heart.fill")
                                            .foregroundColor(.red)
                                            .font(.system(size: 20))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("1 pt")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("per like")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 8) {
                                        Image(systemName: "play.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 20))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("2 pts")
                                                .font(.system(size: 18, weight: .bold))
                                                .foregroundColor(.white)
                                            Text("per play")
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                        
                        // Giving points (engaging)
                        VStack(spacing: 16) {
                            Text("When You Discover Others' Music:")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            VStack(spacing: 12) {
                                HStack(spacing: 16) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "heart.fill")
                                            .foregroundColor(.pink)
                                            .font(.system(size: 18))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("+0.25")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.pink)
                                            Text("for liking")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 8) {
                                        Image(systemName: "play.fill")
                                            .foregroundColor(.cyan)
                                            .font(.system(size: 18))
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("+0.5")
                                                .font(.system(size: 16, weight: .bold))
                                                .foregroundColor(.cyan)
                                            Text("for playing")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                        
                        // Daily reset info
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(beatrooPink)
                                .font(.system(size: 20))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Daily Reset")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text("Leaderboard resets every day at midnight")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(16)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        isPresented = false
                    }
                    .foregroundColor(beatrooPink)
                }
            }
        }
    }
}

struct ProfileInfoCard: View {
    let icon: String
    let title: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                Text(value)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
} 