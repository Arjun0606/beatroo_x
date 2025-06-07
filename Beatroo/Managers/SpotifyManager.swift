import SwiftUI

// Full Spotify SDK implementation with real authentication and track detection
class SpotifyManager: NSObject, ObservableObject, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    // Client ID from your Spotify Developer Dashboard
    private let clientID = "9b3615b5699e4b8d8da6222ebef7a99c"
    private let redirectURI = URL(string: "beatroo://spotify-callback")!
    
    @Published var isConnected = false
    @Published var currentTrack: SpotifyTrack?
    @Published var connectionStatus = "Disconnected"
    
    // Spotify SDK components
    private var configuration: SPTConfiguration!
    private var appRemote: SPTAppRemote!
    
    override init() {
        super.init()
        print("SpotifyManager: Initializing FULL SDK MODE - Framework Embedded!")
        setupSpotifyConfiguration()
        _ = checkSpotifyInstalled()
        
        // Try to restore saved connection
        restoreConnection()
    }
    
    private func setupSpotifyConfiguration() {
        configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURI)
        configuration.playURI = nil // We don't need to play anything on connect
        
        appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        appRemote.delegate = self
    }
    
    // Check if Spotify is installed
    func checkSpotifyInstalled() -> Bool {
        guard let spotifyURL = URL(string: "spotify:") else { 
            print("SpotifyManager: Invalid Spotify URL")
            return false 
        }
        let installed = UIApplication.shared.canOpenURL(spotifyURL)
        print("SpotifyManager: Spotify installed: \(installed)")
        return installed
    }
    
    // Launch Spotify app if needed and wait for it to be ready
    private func launchSpotifyIfNeeded(completion: @escaping () -> Void) {
        print("SpotifyManager: Ensuring Spotify is running...")
        
        // Try to open Spotify to make sure it's running
        if let spotifyURL = URL(string: "spotify:") {
            UIApplication.shared.open(spotifyURL, options: [:]) { success in
                if success {
                    print("SpotifyManager: Spotify launched successfully")
                    // Give Spotify time to fully start up
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        completion()
                    }
                } else {
                    print("SpotifyManager: Failed to launch Spotify")
                    completion()
                }
            }
        } else {
            completion()
        }
    }
    
    // Connect to Spotify with full authentication
    func connect() {
        print("SpotifyManager: Starting FULL SDK connection process")
        
        guard checkSpotifyInstalled() else {
            print("SpotifyManager: Spotify not installed")
            DispatchQueue.main.async {
                self.connectionStatus = "Spotify app not installed"
            }
            return
        }
        
        guard !appRemote.isConnected else {
            print("SpotifyManager: Already connected")
            return
        }
        
        DispatchQueue.main.async {
            self.connectionStatus = "Connecting..."
        }
        
        // Check for saved token first
        if let savedToken = getSavedAccessToken() {
            print("SpotifyManager: Using saved token")
            appRemote.connectionParameters.accessToken = savedToken
            
            // Try to launch Spotify first, then connect
            launchSpotifyIfNeeded {
                self.attemptConnectionWithFallback(retryCount: 2)
            }
        } else if appRemote.connectionParameters.accessToken != nil {
            print("SpotifyManager: Using existing token")
            launchSpotifyIfNeeded {
                self.attemptConnectionWithFallback(retryCount: 2)
            }
        } else {
            print("SpotifyManager: No token found, starting authorization flow")
            // This will open Spotify app for authorization
            appRemote.authorizeAndPlayURI("")
        }
    }
    
    // Handle callback URL from Spotify authorization
    func handleCallback(url: URL) -> Bool {
        print("SpotifyManager: Handling callback URL: \(url.absoluteString)")
        
        let parameters = appRemote.authorizationParameters(from: url)
        
        if let accessToken = parameters?[SPTAppRemoteAccessTokenKey] {
            print("SpotifyManager: Received access token")
            appRemote.connectionParameters.accessToken = accessToken
            
            // Save token for persistence
            saveAccessToken(accessToken)
            
            appRemote.connect()
            return true
        } else if let errorDescription = parameters?[SPTAppRemoteErrorDescriptionKey] {
            print("SpotifyManager: Authorization error: \(errorDescription)")
            DispatchQueue.main.async {
                self.connectionStatus = "Authorization failed: \(errorDescription)"
            }
            return false
        }
        
        return false
    }
    
    // Get current playing track from Spotify
    func getCurrentTrack() {
        guard appRemote.isConnected else {
            print("SpotifyManager: Not connected, cannot get track")
            DispatchQueue.main.async {
                self.currentTrack = nil
            }
            return
        }
        
        print("SpotifyManager: Requesting current track")
        appRemote.playerAPI?.getPlayerState { [weak self] result, error in
            print("SpotifyManager: 📥 RESPONSE RECEIVED - Error: \(error?.localizedDescription ?? "none"), Result: \(result != nil ? "YES" : "NO")")
            
            if let error = error {
                print("SpotifyManager: ❌ Error getting player state: \(error)")
                
                // Check if it's an authorization error
                if error.localizedDescription.contains("not_authorized") || 
                   error.localizedDescription.contains("authorization") ||
                   (error as NSError).code == -3000 {
                    print("SpotifyManager: 🔑 Authorization error detected - clearing token and forcing reauth")
                    self?.clearSavedToken()
                    
                    DispatchQueue.main.async {
                        self?.connectionStatus = "Authorization expired - please reconnect"
                        self?.isConnected = false
                        self?.currentTrack = nil
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self?.currentTrack = nil
                }
                return
            }
            
            guard let playerState = result as? SPTAppRemotePlayerState else {
                print("SpotifyManager: ❌ No player state available - result type: \(type(of: result))")
                DispatchQueue.main.async {
                    self?.currentTrack = nil
                }
                return
            }
            
            print("SpotifyManager: ✅ Player state received - isPaused: \(playerState.isPaused), track: \(playerState.track.name)")
            
            if playerState.isPaused {
                print("SpotifyManager: ⏸️ Spotify is paused, clearing track")
                DispatchQueue.main.async {
                    self?.currentTrack = nil
                }
                return
            }
            
            print("SpotifyManager: 🎵 Track found - updating: \(playerState.track.name) by \(playerState.track.artist.name)")
            self?.updateCurrentTrack(from: playerState)
        }
    }
    
    private func updateCurrentTrack(from playerState: SPTAppRemotePlayerState) {
        let track = playerState.track
        print("SpotifyManager: 🔄 updateCurrentTrack called - track: \(track.name) by \(track.artist.name)")
        
        // First, set the track immediately without artwork
        let spotifyTrack = SpotifyTrack(
            id: track.uri,
            name: track.name,
            artist: track.artist.name,
            album: track.album.name,
            artworkURL: nil,
            artworkImage: nil
        )
        
        DispatchQueue.main.async {
            self.currentTrack = spotifyTrack
            print("SpotifyManager: ✅ Track IMMEDIATELY updated in UI: \(track.name)")
            
            // Notify coordinator of track change
            NotificationCenter.default.post(name: NSNotification.Name("SpotifyTrackChanged"), object: nil)
        }
        
        // Then fetch artwork asynchronously
        appRemote.imageAPI?.fetchImage(forItem: track, with: CGSize(width: 300, height: 300)) { [weak self] image, error in
            if let error = error {
                print("SpotifyManager: ⚠️ Error fetching artwork: \(error)")
            } else {
                print("SpotifyManager: 🖼️ Artwork fetched successfully")
            }
            
            DispatchQueue.main.async {
                self?.currentTrack = SpotifyTrack(
                    id: track.uri,
                    name: track.name,
                    artist: track.artist.name,
                    album: track.album.name,
                    artworkURL: nil,
                    artworkImage: image as? UIImage
                )
                print("SpotifyManager: 🖼️ Track updated with artwork")
                
                // Notify coordinator of track change again with artwork
                NotificationCenter.default.post(name: NSNotification.Name("SpotifyTrackChanged"), object: nil)
            }
        }
    }
    
    // Disconnect from Spotify
    func disconnect() {
        print("SpotifyManager: Disconnecting")
        if appRemote.isConnected {
            appRemote.disconnect()
        }
        
        // Clear saved token when manually disconnecting
        clearSavedToken()
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.currentTrack = nil
            self.connectionStatus = "Disconnected"
        }
    }
    
    // MARK: - SPTAppRemoteDelegate
    
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("SpotifyManager: ✅ Connection established!")
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = "Connected"
            // Notify other parts of the app about connection change
            NotificationCenter.default.post(name: NSNotification.Name("SpotifyConnectionChanged"), object: nil)
        }
        
        // Set up player state monitoring
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { [weak self] result, error in
            if let error = error {
                print("SpotifyManager: Failed to subscribe to player state: \(error)")
            } else {
                print("SpotifyManager: Successfully subscribed to player state")
                // Get initial track immediately and then periodically
                self?.getCurrentTrack()
                
                // Set up periodic track checking
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.getCurrentTrack()
                }
            }
        })
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        let errorMsg = error?.localizedDescription ?? "unknown error"
        print("SpotifyManager: ❌ Connection failed: \(errorMsg)")
        
        var userFriendlyMessage = "Connection failed"
        
        // Provide more user-friendly error messages
        if errorMsg.contains("Connection refused") || errorMsg.contains("Stream error") {
            userFriendlyMessage = "Spotify not ready - make sure Spotify is open and playing music"
        } else if errorMsg.contains("token") || errorMsg.contains("authorization") {
            userFriendlyMessage = "Authorization expired - please reconnect"
            clearSavedToken()
        } else if errorMsg.contains("network") {
            userFriendlyMessage = "Network error - check your connection"
        }
        
        // If we have a saved token but connection failed, it might be expired
        if getSavedAccessToken() != nil && (errorMsg.contains("token") || errorMsg.contains("authorization")) {
            print("SpotifyManager: Token might be expired, clearing saved token")
            clearSavedToken()
        }
        
        DispatchQueue.main.async {
            self.isConnected = false
            self.connectionStatus = userFriendlyMessage
            // Notify other parts of the app about connection change
            NotificationCenter.default.post(name: NSNotification.Name("SpotifyConnectionChanged"), object: nil)
        }
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("SpotifyManager: Disconnected: \(error?.localizedDescription ?? "no error")")
        DispatchQueue.main.async {
            self.isConnected = false
            self.currentTrack = nil
            self.connectionStatus = "Disconnected"
        }
    }
    
    // MARK: - SPTAppRemotePlayerStateDelegate
    
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        print("SpotifyManager: 🎵 Player state changed - track: \(playerState.track.name)")
        updateCurrentTrack(from: playerState)
    }
    
    // MARK: - Token Persistence
    
    private func saveAccessToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "SpotifyAccessToken")
        UserDefaults.standard.synchronize()
        print("SpotifyManager: Access token saved")
    }
    
    private func getSavedAccessToken() -> String? {
        return UserDefaults.standard.string(forKey: "SpotifyAccessToken")
    }
    
    private func clearSavedToken() {
        UserDefaults.standard.removeObject(forKey: "SpotifyAccessToken")
        UserDefaults.standard.synchronize()
        print("SpotifyManager: Access token cleared")
    }
    
    private func restoreConnection() {
        guard checkSpotifyInstalled() else {
            print("SpotifyManager: Spotify not installed, skipping restore")
            return
        }
        
        if let savedToken = getSavedAccessToken() {
            print("SpotifyManager: Restoring connection with saved token")
            appRemote.connectionParameters.accessToken = savedToken
            
            // Try to connect automatically with retry logic
            attemptConnection(retryCount: 3)
        } else {
            print("SpotifyManager: No saved token found")
        }
    }
    
    // New method that tries saved token first, then falls back to authorization
    private func attemptConnectionWithFallback(retryCount: Int) {
        guard retryCount > 0 else {
            print("SpotifyManager: Token connection failed, starting fresh authorization")
            DispatchQueue.main.async {
                self.connectionStatus = "Authorizing..."
            }
            // Clear the potentially invalid token
            clearSavedToken()
            // Start fresh authorization flow
            appRemote.authorizeAndPlayURI("")
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !self.appRemote.isConnected {
                print("SpotifyManager: Connection attempt \(3 - retryCount)")
                self.appRemote.connect()
                
                // Check if connected after a delay, retry if not
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if !self.appRemote.isConnected {
                        print("SpotifyManager: Attempt \(3 - retryCount) failed, retrying...")
                        self.attemptConnectionWithFallback(retryCount: retryCount - 1)
                    } else {
                        print("SpotifyManager: Successfully connected on attempt \(3 - retryCount)")
                    }
                }
            }
        }
    }
    
    private func attemptConnection(retryCount: Int) {
        guard retryCount > 0 else {
            print("SpotifyManager: Failed to connect after retries")
            DispatchQueue.main.async {
                self.connectionStatus = "Connection failed - ensure Spotify is playing music"
            }
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if !self.appRemote.isConnected {
                print("SpotifyManager: Connection attempt \(4 - retryCount)")
                self.appRemote.connect()
                
                // Check if connected after a delay, retry if not
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if !self.appRemote.isConnected {
                        print("SpotifyManager: Attempt \(4 - retryCount) failed, retrying...")
                        self.attemptConnection(retryCount: retryCount - 1)
                    } else {
                        print("SpotifyManager: Successfully connected on attempt \(4 - retryCount)")
                    }
                }
            }
        }
    }
    
    // Public method to force reconnection
    func reconnectIfPossible() {
        guard !appRemote.isConnected else {
            print("SpotifyManager: Already connected")
            return
        }
        
        if let savedToken = getSavedAccessToken() {
            print("SpotifyManager: Attempting reconnection with saved token")
            appRemote.connectionParameters.accessToken = savedToken
            
            launchSpotifyIfNeeded {
                self.attemptConnection(retryCount: 3)
            }
        } else {
            print("SpotifyManager: No saved token for reconnection")
        }
    }
    
    // Public method to force fresh authorization (when token is expired)
    func forceReauthorization() {
        print("SpotifyManager: 🔄 FORCING FRESH AUTHORIZATION")
        
        // Disconnect if connected
        if appRemote.isConnected {
            appRemote.disconnect()
        }
        
        // Clear any saved token
        clearSavedToken()
        
        // Clear current track
        DispatchQueue.main.async {
            self.currentTrack = nil
            self.isConnected = false
            self.connectionStatus = "Starting fresh authorization..."
        }
        
        // Start fresh authorization flow
        launchSpotifyIfNeeded {
            print("SpotifyManager: Starting fresh auth flow")
            self.appRemote.authorizeAndPlayURI("")
        }
    }
    

    
    // Check if Spotify app is actively running (not just installed)
    func isSpotifyRunning() -> Bool {
        // This is a simplified check - in reality, we can't directly check if another app is running
        // But we can check if we can establish a connection
        return appRemote.isConnected
    }
}

// Enhanced model for Spotify track with full metadata
struct SpotifyTrack {
    let id: String
    let name: String
    let artist: String
    let album: String
    let artworkURL: URL?
    var artworkImage: UIImage?
    
    // Computed properties for UI
    var providerName: String {
        return "Spotify"
    }
    
    var providerColor: Color {
        return .green
    }
    
    var displayName: String {
        return "\(name) - \(artist)"
    }
}

// MARK: - Full SDK Implementation Instructions
/*
To fully implement Spotify SDK:

1. Download the SDK from: https://github.com/spotify/ios-sdk
2. Add SpotifyiOS.xcframework to your project
3. Uncomment the import in your Bridging Header
4. Register your app in Spotify Developer Dashboard
5. Add required URL scheme for redirect URI
6. Replace this class with:

```swift
import SwiftUI
// SpotifyiOS will be imported via bridging header

class SpotifyManager: NSObject, ObservableObject, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    private let clientID = "YOUR_SPOTIFY_CLIENT_ID"
    private let redirectURI = URL(string: "beatroo://spotify-callback")!
    
    @Published var isConnected = false
    @Published var currentTrack: SpotifyTrack?
    
    lazy var configuration: SPTConfiguration = {
        let config = SPTConfiguration(clientID: clientID, redirectURL: redirectURI)
        // Optional: Set token swap URL if you have a server for token refresh
        return config
    }()
    
    lazy var appRemote: SPTAppRemote = {
        let appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        appRemote.delegate = self
        return appRemote
    }()
    
    func connect() {
        guard !appRemote.isConnected else { return }
        appRemote.authorizeAndPlayURI("")
    }
    
    func disconnect() {
        if appRemote.isConnected {
            appRemote.disconnect()
        }
    }
    
    // Handle Spotify callback
    func handleCallback(url: URL) -> Bool {
        let parameters = appRemote.authorizationParameters(from: url)
        
        if let accessToken = parameters?[SPTAppRemoteAccessTokenKey] {
            appRemote.connectionParameters.accessToken = accessToken
            appRemote.connect()
            return true
        } else if let errorDescription = parameters?[SPTAppRemoteErrorDescriptionKey] {
            print("SpotifyManager: Authorization error: \(errorDescription)")
            return false
        }
        return false
    }
    
    // MARK: - SPTAppRemoteDelegate
    
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        isConnected = true
        appRemote.playerAPI?.delegate = self
        appRemote.playerAPI?.subscribe(toPlayerState: { [weak self] result, error in
            if let error = error {
                print("SpotifyManager: Failed to subscribe: \(error)")
            }
        })
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        isConnected = false
        print("SpotifyManager: Failed to connect: \(error?.localizedDescription ?? "unknown error")")
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        isConnected = false
        print("SpotifyManager: Disconnected: \(error?.localizedDescription ?? "no error")")
    }
    
    // MARK: - SPTAppRemotePlayerStateDelegate
    
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        let track = playerState.track
        appRemote.imageAPI?.fetchImage(forItem: track, with: CGSize(width: 300, height: 300), callback: { [weak self] image, error in
            if let error = error {
                print("SpotifyManager: Error fetching image: \(error)")
                return
            }
            
            DispatchQueue.main.async {
                self?.currentTrack = SpotifyTrack(
                    id: track.uri,
                    name: track.name,
                    artist: track.artist.name,
                    album: track.album.name,
                    artworkURL: nil,
                    artworkImage: image as? UIImage
                )
            }
        })
    }
}
*/ 