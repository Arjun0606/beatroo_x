import SwiftUI
import MediaPlayer

struct NowPlayingView: View {
    @EnvironmentObject var musicCoordinator: MusicServiceCoordinator
    @EnvironmentObject var socialMusicManager: SocialMusicManager
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var trendingManager = TrendingMusicManager()
    @State private var isExpanded = false
    @State private var showLocationAlert = false
    @State private var selectedTab: Int = 0 // 0 = Nearby, 1 = Trending
    
    private let beatrooPink = Color(hex: "B01E68") // Consistent Beatroo pink color
    private let artworkSize: CGFloat = 100
    private let expandedArtworkSize: CGFloat = UIScreen.main.bounds.width - 32
    
    var body: some View {
        VStack(spacing: 0) {
            // Now Playing Bar at the top
            if let currentTrack = musicCoordinator.currentTrack {
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                        // Artwork
                        if let artwork = currentTrack.artwork {
                            Image(uiImage: artwork)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: isExpanded ? expandedArtworkSize : artworkSize, 
                                       height: isExpanded ? expandedArtworkSize : artworkSize)
                                .cornerRadius(12)
                                .shadow(radius: isExpanded ? 10 : 0)
                                .animation(.spring(), value: isExpanded)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: isExpanded ? expandedArtworkSize : artworkSize, 
                                       height: isExpanded ? expandedArtworkSize : artworkSize)
                                .animation(.spring(), value: isExpanded)
                        }
                        
                        if !isExpanded {
                            // Track Info (only shown in collapsed state)
                            VStack(alignment: .leading, spacing: 8) {
                                Text(currentTrack.title)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                
                                HStack(spacing: 4) {
                                    Text(currentTrack.artist)
                                        .font(.system(size: 19, weight: .bold))
                                        .foregroundColor(.gray)
                                    Text("•")
                                        .font(.system(size: 19, weight: .bold))
                                        .foregroundColor(.gray)
                                    Text(currentTrack.platform)
                                        .font(.system(size: 19, weight: .regular))
                                        .foregroundColor(currentTrack.musicProvider.color)
                                }
                                .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, isExpanded ? 20 : 10)
                    .frame(maxWidth: .infinity)
                    
                    if isExpanded {
                        // Expanded track info
                        VStack(spacing: 16) {
                            VStack(spacing: 8) {
                                Text(currentTrack.title)
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                
                                HStack(spacing: 4) {
                                    Text(currentTrack.artist)
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(.gray)
                                    Text("•")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundColor(.gray)
                                    Text(currentTrack.platform)
                                        .font(.system(size: 22, weight: .regular))
                                        .foregroundColor(currentTrack.musicProvider.color)
                                }
                                
                                Text(currentTrack.album)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.gray.opacity(0.8))
                            }
                            .padding(.top, 20)
                            
                            // Platform indicator
                            HStack(spacing: 8) {
                                Image(systemName: "music.note")
                                    .foregroundColor(currentTrack.musicProvider.color)
                                Text(currentTrack.platform)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(currentTrack.musicProvider.color)
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }
                .background(Color.black)
                .onTapGesture {
                    withAnimation(.spring()) {
                        isExpanded.toggle()
                    }
                }
            }
            
            // Main Content with Tabs
            if !isExpanded {
                VStack(spacing: 0) {
                    // Header with Tab Picker
                    VStack(spacing: 16) {
                        HStack {
                            Text("Discover")
                                .font(.system(size: 34, weight: .bold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            if selectedTab == 0 && (locationManager.authorizationStatus == .authorizedWhenInUse ||
                               locationManager.authorizationStatus == .authorizedAlways) {
                                Text("\(socialMusicManager.nearbyUsers.count)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(beatrooPink)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(beatrooPink.opacity(0.2))
                                    .cornerRadius(12)
                            }
                        }
                        
                        // Tab Picker
                        HStack(spacing: 0) {
                            TabButton(title: "Nearby", isSelected: selectedTab == 0) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedTab = 0
                                }
                            }
                            
                            TabButton(title: "Trending", isSelected: selectedTab == 1) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedTab = 1
                                }
                            }
                        }
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    
                    // Content based on selected tab
                    if selectedTab == 0 {
                        // Nearby Content
                        VStack(spacing: 0) {
                            // Location Status
                            if locationManager.authorizationStatus != .authorizedWhenInUse &&
                               locationManager.authorizationStatus != .authorizedAlways {
                                NearbyLocationPermissionView()
                            } else if let city = locationManager.currentCity {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .foregroundColor(beatrooPink)
                                    Text("Discovering in \(city)")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                            }
                            
                            // Nearby Users List
                            if socialMusicManager.nearbyUsers.isEmpty {
                                NearbyEmptyStateView()
                            } else {
                                ScrollView {
                                    LazyVStack(spacing: 16) {
                                        ForEach(socialMusicManager.nearbyUsers) { user in
                                            NearbyUserCardView(user: user)
                                                .environmentObject(socialMusicManager)
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.top, 20)
                                }
                            }
                        }
                    } else {
                        // Trending Content
                        ScrollView {
                            if let city = locationManager.currentCity {
                                TrendingMusicView(trendingManager: trendingManager, city: city)
                                    .padding(.top, 20)
                            } else {
                                VStack(spacing: 16) {
                                    Image(systemName: "location.slash")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    
                                    Text("Location needed for trending music")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                            }
                        }
                    }
                    
                    Spacer()
                }
                .background(Color.black)
            }
        }
        .onAppear {
            musicCoordinator.refreshNowPlaying()
            setupLocationAndDiscovery()
        }
        .onDisappear {
            socialMusicManager.stopDiscoveringNearbyUsers()
        }
        .alert("Location Required", isPresented: $showLocationAlert) {
            Button("Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable location access to discover nearby music.")
        }
    }
}

// MARK: - Tab Button Component
struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    private let beatrooPink = Color(hex: "B01E68")
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    isSelected ? beatrooPink : Color.clear
                )
                .cornerRadius(8)
        }
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
    
    private func setupLocationAndDiscovery() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestLocationPermission()
        case .authorizedWhenInUse, .authorizedAlways:
            socialMusicManager.startDiscoveringNearbyUsers()
        case .denied, .restricted:
            showLocationAlert = true
        @unknown default:
            break
        }
    }
}

// MARK: - Supporting Views

struct NearbyLocationPermissionView: View {
    @EnvironmentObject var locationManager: LocationManager
    private let beatrooPink = Color(hex: "B01E68")
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "location.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(beatrooPink)
            
            VStack(spacing: 12) {
                Text("Discover Nearby Music")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("See what people within 35 meters are listening to and share your musical taste with others nearby.")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Button(action: {
                locationManager.requestLocationPermission()
            }) {
                Text("Enable Location")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(beatrooPink)
                    .cornerRadius(28)
            }
            .padding(.horizontal, 40)
            
            Spacer()
        }
    }
}

struct NearbyEmptyStateView: View {
    private let beatrooPink = Color(hex: "B01E68")
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "music.note.house.fill")
                .font(.system(size: 60))
                .foregroundColor(beatrooPink.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("No Vibes Nearby")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("No one within 35 meters is sharing their music right now. Start playing something to let others discover your taste!")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
}

struct NearbyUserCardView: View {
    let user: NearbyUser
    @EnvironmentObject var socialMusicManager: SocialMusicManager
    @State private var isLiked = false
    @State private var hasPlayed = false
    
    private let beatrooPink = Color(hex: "B01E68")
    
    var body: some View {
        VStack(spacing: 0) {
            // User Info and Track
            HStack(spacing: 12) {
                // Profile Picture
                AsyncImage(url: user.profilePhotoURL.flatMap(URL.init)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                // User and Track Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let track = user.currentTrack {
                        HStack(spacing: 4) {
                            Text(track.title)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(beatrooPink)
                            Text("•")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            Text(track.artist)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .lineLimit(1)
                        
                        Text(track.provider)
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.8))
                    }
                    
                    if let distance = user.distance {
                        Text("\(Int(distance))m away")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 12) {
                    // Vibe Button (Like)
                    Button(action: {
                        Task {
                            await socialMusicManager.likeTrack(user)
                            isLiked = true
                        }
                    }) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 20))
                            .foregroundColor(isLiked ? .red : .white)
                    }
                    .disabled(isLiked)
                    
                    // Play Button
                    Button(action: {
                        Task {
                            await socialMusicManager.playTrack(user)
                            hasPlayed = true
                        }
                    }) {
                        Image(systemName: hasPlayed ? "checkmark.circle.fill" : "play.circle")
                            .font(.system(size: 20))
                            .foregroundColor(hasPlayed ? .green : beatrooPink)
                    }
                    .disabled(hasPlayed)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

// Extension to create Color from hex string
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 