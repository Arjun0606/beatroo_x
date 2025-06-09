import SwiftUI

struct NearbyMusicView: View {
    @EnvironmentObject var socialMusicManager: SocialMusicManager
    @EnvironmentObject var locationManager: LocationManager
    @State private var showLocationAlert = false
    
    private let beatrooPink = Color(hex: "B01E68")
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Nearby Vibes")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if locationManager.authorizationStatus == .authorizedWhenInUse ||
                       locationManager.authorizationStatus == .authorizedAlways {
                        Text("\(socialMusicManager.nearbyUsers.count)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(beatrooPink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(beatrooPink.opacity(0.2))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Location Status
                if locationManager.authorizationStatus != .authorizedWhenInUse &&
                   locationManager.authorizationStatus != .authorizedAlways {
                    LocationPermissionView()
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
                    EmptyNearbyView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(socialMusicManager.nearbyUsers) { user in
                                NearbyUserCard(user: user)
                                    .environmentObject(socialMusicManager)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
                
                Spacer()
            }
        }
        .onAppear {
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

struct LocationPermissionView: View {
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

struct EmptyNearbyView: View {
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

struct NearbyUserCard: View {
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
                
                // Track Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(user.displayName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        if let distance = user.distance {
                            Text("\(Int(distance))m")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if let track = user.currentTrack {
                        Text(track.title)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(beatrooPink)
                            .lineLimit(1)
                        
                        HStack {
                            Text(track.artist)
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            // Provider Badge
                            HStack(spacing: 4) {
                                Image(systemName: track.provider == "Spotify" ? "music.note" : "music.note")
                                    .font(.system(size: 10))
                                Text(track.provider)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .foregroundColor(track.provider == "Spotify" ? .green : beatrooPink)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                        }
                    }
                }
                
                Spacer()
            }
            .padding()
            
            // Action Buttons
            if user.currentTrack != nil {
                HStack(spacing: 12) {
                    // Like Button
                    Button(action: {
                        Task {
                            await socialMusicManager.likeTrack(user)
                            isLiked = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 14))
                            Text("Vibe")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(isLiked ? .red : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(isLiked ? Color.red.opacity(0.2) : Color.gray.opacity(0.2))
                        .cornerRadius(18)
                    }
                    .disabled(isLiked)
                    
                    // Play Button
                    Button(action: {
                        Task {
                            await socialMusicManager.playTrack(user)
                            hasPlayed = true
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: hasPlayed ? "checkmark.circle.fill" : "play.fill")
                                .font(.system(size: 14))
                            Text(hasPlayed ? "Playing" : "Play")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(hasPlayed ? .green : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(hasPlayed ? Color.green.opacity(0.2) : beatrooPink)
                        .cornerRadius(18)
                    }
                    .disabled(hasPlayed)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
    }
} 