import SwiftUI

struct SpotifyTestView: View {
    @StateObject private var spotifyManager = SpotifyManager()
    @EnvironmentObject var musicCoordinator: MusicServiceCoordinator
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Spotify Integration Test")
                .font(.title)
                .foregroundColor(.white)
            
            Text("Available Services:")
                .font(.headline)
                .foregroundColor(.white)
            
            ForEach(musicCoordinator.availableServices, id: \.self) { service in
                HStack {
                    Circle()
                        .fill(service.color)
                        .frame(width: 12, height: 12)
                    Text(service.rawValue)
                        .foregroundColor(.white)
                }
            }
            
            VStack(spacing: 10) {
                Text("Spotify Status:")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("Installed: \(spotifyManager.checkSpotifyInstalled() ? "✅" : "❌")")
                    .foregroundColor(.white)
                
                Text("Connected: \(spotifyManager.isConnected ? "✅" : "❌")")
                    .foregroundColor(.white)
            }
            
            if let currentTrack = musicCoordinator.currentTrack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Now Playing:")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Title: \(currentTrack.title)")
                        .foregroundColor(.white)
                    
                    Text("Artist: \(currentTrack.artist)")
                        .foregroundColor(.white)
                    
                    Text("Source: \(currentTrack.providerName)")
                        .foregroundColor(currentTrack.providerColor)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(10)
            }
            
            if spotifyManager.checkSpotifyInstalled() {
                Button("Connect to Spotify") {
                    spotifyManager.connect()
                }
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
            } else {
                Button("Install Spotify") {
                    if let url = URL(string: "https://apps.apple.com/app/spotify-music/id324684580") {
                        UIApplication.shared.open(url)
                    }
                }
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
            
            Button("Refresh Now Playing") {
                musicCoordinator.refreshNowPlaying()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            
            Spacer()
        }
        .padding()
        .background(Color.black)
    }
} 