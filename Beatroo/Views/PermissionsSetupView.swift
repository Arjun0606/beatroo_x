import SwiftUI
import MediaPlayer

struct PermissionsSetupView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var musicCoordinator: MusicServiceCoordinator
    
    @State private var currentStep = 0
    @State private var musicPermissionGranted = false
    @State private var spotifyConnected = false
    @State private var isConnectingSpotify = false
    @State private var showSkipAlert = false
    
    private let steps = [
        PermissionStep(
            title: "Music Library Access",
            description: "Allow Beatroo to detect what you're listening to across all your music apps",
            icon: "music.note",
            isRequired: true
        ),
        PermissionStep(
            title: "Connect Spotify",
            description: "Get the full experience by connecting your Spotify account for seamless music detection",
            icon: "music.note.list",
            isRequired: false
        )
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Header
                VStack(spacing: 15) {
                    Text("Let's Set You Up")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Just a few quick steps to get you started")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)
                
                // Progress Indicator
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index <= currentStep ? Color.beatrooPink : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)
                            .animation(.easeInOut, value: currentStep)
                    }
                }
                
                Spacer()
                
                // Current Step Content
                VStack(spacing: 40) {
                    let step = steps[currentStep]
                    
                    // Icon
                    ZStack {
                        Circle()
                            .fill(Color.beatrooPink.opacity(0.2))
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: step.icon)
                            .font(.system(size: 50, weight: .light))
                            .foregroundColor(Color.beatrooPink)
                    }
                    
                    // Content
                    VStack(spacing: 15) {
                        Text(step.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text(step.description)
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                }
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 15) {
                    // Main Action Button
                    Button(action: handleMainAction) {
                        HStack {
                            if isConnectingSpotify {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Connecting...")
                            } else {
                                Text(getMainActionText())
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.beatrooPink)
                    .foregroundColor(.white)
                    .cornerRadius(28)
                    .disabled(isConnectingSpotify)
                    
                    // Skip/Skip All Button (for optional steps)
                    if !steps[currentStep].isRequired {
                        Button(action: { showSkipAlert = true }) {
                            Text("Skip Spotify")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    // Complete Setup Button (on last step if optional step is done)
                    if currentStep == steps.count - 1 && (spotifyConnected || !steps[currentStep].isRequired) {
                        Button(action: completeSetup) {
                            Text("Complete Setup")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(28)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            checkExistingPermissions()
        }
        .alert("Skip Spotify Connection?", isPresented: $showSkipAlert) {
            Button("Skip", role: .destructive) {
                completeSetup()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("You can connect Spotify later in your profile settings. You'll still be able to see music from Apple Music and other apps.")
        }
    }
    
    private func checkExistingPermissions() {
        // Check music library permission
        let status = MPMediaLibrary.authorizationStatus()
        musicPermissionGranted = (status == .authorized)
        
        // Check Spotify connection
        spotifyConnected = musicCoordinator.spotifyManager.isConnected
        
        // Skip to next step if current permission is already granted
        if currentStep == 0 && musicPermissionGranted {
            currentStep = 1
        }
    }
    
    private func getMainActionText() -> String {
        switch currentStep {
        case 0:
            return musicPermissionGranted ? "Music Access Granted ✓" : "Allow Music Access"
        case 1:
            return spotifyConnected ? "Spotify Connected ✓" : "Connect Spotify"
        default:
            return "Continue"
        }
    }
    
    private func handleMainAction() {
        switch currentStep {
        case 0:
            requestMusicPermission()
        case 1:
            connectSpotify()
        default:
            break
        }
    }
    
    private func requestMusicPermission() {
        MPMediaLibrary.requestAuthorization { status in
            DispatchQueue.main.async {
                self.musicPermissionGranted = (status == .authorized)
                if self.musicPermissionGranted {
                    // Move to next step after a brief delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.currentStep = 1
                    }
                }
            }
        }
    }
    
    private func connectSpotify() {
        guard !isConnectingSpotify else { return }
        
        isConnectingSpotify = true
        
        // Connect to Spotify
        musicCoordinator.connectToSpotify()
        
        // Set up observer to detect when connection is established
        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SpotifyConnectionChanged"),
            object: nil,
            queue: .main
        ) { _ in
            self.spotifyConnected = self.musicCoordinator.spotifyManager.isConnected
            self.isConnectingSpotify = false
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
        
        // Also check after a delay as fallback
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.spotifyConnected = self.musicCoordinator.spotifyManager.isConnected
            self.isConnectingSpotify = false
            if let observer = observer {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    private func completeSetup() {
        // Mark setup as complete and transition to main app
        UserDefaults.standard.set(true, forKey: "PermissionsSetupCompleted")
        authManager.updateAuthState()
    }
}

// Helper struct for permission steps
struct PermissionStep {
    let title: String
    let description: String
    let icon: String
    let isRequired: Bool
}

#Preview {
    PermissionsSetupView()
        .environmentObject(AuthenticationManager())
        .environmentObject(MusicServiceCoordinator())
} 