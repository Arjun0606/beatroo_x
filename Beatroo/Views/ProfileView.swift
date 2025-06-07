import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var musicCoordinator: MusicServiceCoordinator
    @State private var showSignOutAlert = false
    @State private var isConnectingSpotify = false
    
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
                                
                                if let age = user.age {
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
                            VStack(alignment: .leading, spacing: 15) {
                                Text("Music Services")
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 20)
                                
                                VStack(spacing: 15) {
                                    // Spotify Connection
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
                                        
                                        if !musicCoordinator.spotifyManager.isConnected {
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
                                        } else {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 20))
                                        }
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                                    
                                    // Apple Music (always available)
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
                                .padding(.horizontal, 20)
                            }
                            .padding(.top, 30)
                        }
                        
                        Spacer(minLength: 100)
                    }
                }
            }
        }
        .alert("Sign Out", isPresented: $showSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func connectSpotify() {
        guard !isConnectingSpotify else { return }
        
        isConnectingSpotify = true
        musicCoordinator.connectToSpotify()
        
        // Check connection status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isConnectingSpotify = false
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