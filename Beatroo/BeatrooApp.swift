import SwiftUI
import Firebase
import GoogleSignIn

@main
struct BeatrooApp: App {
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var musicCoordinator = MusicServiceCoordinator()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var socialMusicManager = SocialMusicManager()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(musicCoordinator)
                .environmentObject(locationManager)
                .environmentObject(socialMusicManager)
                .preferredColorScheme(.dark)
                .onOpenURL { url in
                    if url.absoluteString.contains("google") {
                        // Handle Google Sign-In
                        GIDSignIn.sharedInstance.handle(url)
                    } else {
                        // Handle music service callbacks (e.g., Spotify)
                        musicCoordinator.handleCallback(url: url)
                    }
                }
        }
    }
}

// Main content view that handles navigation
struct ContentView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var musicCoordinator: MusicServiceCoordinator
    
    var body: some View {
        Group {
            switch authManager.authState {
            case .loading:
                SplashView()
            case .signedOut:
                SignInView()
            case .needsProfile:
                ProfileCreationView()
            case .needsPermissions:
                PermissionsSetupView()
            case .signedIn:
                MainTabView()
            }
        }
        .animation(.easeInOut, value: authManager.authState)
        .onAppear {
            // Refresh now playing info when the app appears
            musicCoordinator.refreshNowPlaying()
        }
    }
} 