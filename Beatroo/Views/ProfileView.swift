import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var musicCoordinator: MusicServiceCoordinator
    @State private var showSignOutAlert = false
    @State private var showDeleteAlert = false
    @State private var showEditProfile = false
    @State private var isConnectingSpotify = false
    @State private var isDeletingAccount = false
    
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
                                
                                // Display Name
                                Text(user.displayName)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                
                                // Username
                                Text("@\(user.username)")
                                    .font(.system(size: 18))
                                    .foregroundColor(beatrooPink)
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
                // Spotify Connection
                spotifyServiceRow
                
                // Apple Music (always available)
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
                
                // Show detailed status using the enhanced status system
                Text(musicCoordinator.spotifyManager.connectionStatus)
                    .font(.system(size: 14))
                    .foregroundColor(statusColor(for: musicCoordinator.spotifyManager.connectionStatus))
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