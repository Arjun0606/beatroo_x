import SwiftUI
import MediaPlayer

struct NowPlayingView: View {
    @EnvironmentObject var musicCoordinator: MusicServiceCoordinator
    @State private var isExpanded = false
    
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
                            
                            // Playback controls
                            HStack(spacing: 40) {
                                Button(action: { 
                                    // TODO: Implement skip previous for music services
                                }) {
                                    Image(systemName: "backward.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                }
                                
                                Button(action: { 
                                    // TODO: Implement play/pause toggle for music services
                                }) {
                                    Image(systemName: "play.fill") // TODO: Get actual playback state
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                }
                                
                                Button(action: { 
                                    // TODO: Implement skip next for music services
                                }) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(.white)
                                }
                            }
                            .padding(.vertical, 30)
                            
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
            
            // Main Content
            if !isExpanded {
                ZStack {
                    Color.black.edgesIgnoringSafeArea(.all)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Nearby")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.top, 10)
                        
                        Spacer()
                        
                        VStack(spacing: 16) {
                            // Music icon with a more prominent style
                            ZStack {
                                Circle()
                                    .fill(beatrooPink.opacity(0.2))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 40))
                                    .foregroundColor(beatrooPink)
                            }
                            
                            Text("No one nearby")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.white)
                            
                            Text("Looking for music lovers around you...")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            musicCoordinator.refreshNowPlaying()
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