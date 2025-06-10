import SwiftUI

// Full Spotify SDK implementation with real authentication and track detection
class SpotifyManager: NSObject, ObservableObject, SPTAppRemoteDelegate, SPTAppRemotePlayerStateDelegate {
    // Client ID from your Spotify Developer Dashboard
    private let clientID = "9b3615b5699e4b8d8da6222ebef7a99c"
    private let redirectURI = URL(string: "beatroo://spotify-callback")!
    
    @Published var isConnected = false
    @Published var currentTrack: SpotifyTrack?
    @Published var connectionStatus = "Disconnected"
    @Published var isPlaying = false
    
    // Track if user has authorized Spotify (has saved credentials)
    var hasSpotifyCredentials: Bool {
        return getSavedAccessToken() != nil
    }
    
    // Like Apple Music - if we have credentials, we're "connected" (ready to play)
    var isPersistentlyConnected: Bool {
        return hasSpotifyCredentials
    }
    
    // Spotify SDK components
    private var configuration: SPTConfiguration!
    private var appRemote: SPTAppRemote!
    
    // Connection maintenance
    private var connectionMaintenanceTimer: Timer?
    
    // MARK: - Persistent Connection Management
    private var reconnectionTimer: Timer?
    private var reconnectionAttempts: Int = 0
    private let maxReconnectionAttempts: Int = 999 // Essentially unlimited like Apple Music
    
    override init() {
        super.init()
        print("SpotifyManager: Initializing FULL SDK MODE - Framework Embedded!")
        setupSpotifyConfiguration()
        _ = checkSpotifyInstalled()
        
        // Try to restore previous session
        restoreConnection()
        
        // Set initial status based on whether we have credentials
        if hasSpotifyCredentials {
            DispatchQueue.main.async {
                self.connectionStatus = "Ready (authenticated)"
            }
            print("SpotifyManager: Has saved credentials - ready for automatic reconnection")
        } else {
            print("SpotifyManager: No saved credentials - ready for manual authorization")
        }
    }
    
    private func setupSpotifyConfiguration() {
        configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURI)
        configuration.playURI = nil // We don't need to play anything on connect
        
        // Add required scopes for player state access
        configuration.tokenSwapURL = nil
        configuration.tokenRefreshURL = nil
        
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
    
    // Launch Spotify app if needed
    private func launchSpotifyIfNeeded(completion: @escaping () -> Void) {
        print("SpotifyManager: Ensuring Spotify is running...")
        
        // First check if Spotify is installed
        guard checkSpotifyInstalled() else {
            print("SpotifyManager: Spotify not installed")
            DispatchQueue.main.async {
                self.connectionStatus = "Spotify app not installed"
            }
            return
        }
        
        // Try to open Spotify app
        if let spotifyURL = URL(string: "spotify://") {
            UIApplication.shared.open(spotifyURL, options: [:]) { success in
                if success {
                    print("SpotifyManager: Spotify launched successfully")
                    // Give Spotify time to fully launch and initialize
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        completion()
                    }
                } else {
                    print("SpotifyManager: Failed to launch Spotify")
                    // Try anyway - Spotify might already be running
                    completion()
                }
            }
        } else {
            // Fallback - just try to connect
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
            // Use proper authorization with required scopes
            let scopeString = "app-remote-control,user-read-playback-state"
            print("SpotifyManager: Requesting authorization with scopes: \(scopeString)")
            
            // Build authorization URL manually to ensure proper scopes
            let authURLString = "spotify-action://authorize?" +
                "response_type=token&" +
                "client_id=\(clientID)&" +
                "redirect_uri=\(redirectURI.absoluteString)&" +
                "scope=\(scopeString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scopeString)"
            
            if let authURL = URL(string: authURLString) {
                print("SpotifyManager: Opening auth URL: \(authURLString)")
                UIApplication.shared.open(authURL, options: [:]) { success in
                    if !success {
                        print("SpotifyManager: Failed to open authorization URL, falling back to SDK method")
                        self.appRemote.authorizeAndPlayURI("")
                    }
                }
            } else {
                print("SpotifyManager: Invalid auth URL, using SDK authorization")
            appRemote.authorizeAndPlayURI("")
            }
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
                    print("SpotifyManager: 🔑 Authorization error detected - need to reauthorize with proper scopes")
                    self?.clearSavedToken()
                    
                    DispatchQueue.main.async {
                        self?.connectionStatus = "Authorization expired - reconnecting with proper permissions"
                        self?.isConnected = false
                        self?.currentTrack = nil
                        
                        // Force re-authorization with proper scopes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self?.forceReauthorization()
                        }
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
            
            // Update playing state and track regardless of pause state
            DispatchQueue.main.async {
                self?.isPlaying = !playerState.isPaused
            }
            
            print("SpotifyManager: 🎵 Track found - updating: \(playerState.track.name) by \(playerState.track.artist.name), playing: \(!playerState.isPaused)")
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
    
    // Disconnect from Spotify (but keep token for auto-reconnect unless explicitly logging out)
    func disconnect(clearCredentials: Bool = false) {
        print("SpotifyManager: Disconnecting (clearCredentials: \(clearCredentials))")
        
        // Stop timers
        stopConnectionMaintenance()
        stopPersistentReconnection()
        
        if appRemote.isConnected {
            appRemote.disconnect()
        }
        
        // Only clear saved token when explicitly logging out/uninstalling
        if clearCredentials {
        clearSavedToken()
            print("SpotifyManager: Credentials cleared - user explicitly logged out")
        } else {
            print("SpotifyManager: Disconnected but keeping credentials for auto-reconnect")
        }
        
        DispatchQueue.main.async {
            self.isConnected = false
            if clearCredentials {
            self.currentTrack = nil
                self.isPlaying = false
            self.connectionStatus = "Disconnected"
            } else {
                // Like Apple Music - keep showing current track and ready state
                self.connectionStatus = "Ready (will reconnect)"
            }
        }
        
        // If we still have credentials and not explicitly logging out, start reconnection
        if !clearCredentials && getSavedAccessToken() != nil {
            print("SpotifyManager: Starting persistent reconnection after disconnect")
            // Small delay before starting reconnection
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.startPersistentReconnection()
            }
        }
    }
    
    // Method for explicit logout (called when user wants to disconnect permanently)
    func logout() {
        print("SpotifyManager: User explicitly logging out of Spotify")
        disconnect(clearCredentials: true)
    }
    
    // MARK: - SPTAppRemoteDelegate
    
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("SpotifyManager: ✅ Connected successfully!")
        
        // Stop persistent reconnection since we're connected
        stopPersistentReconnection()
        
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = "Connected"
        }
        
        // Subscribe to player state updates
        appRemote.playerAPI?.subscribe(toPlayerState: { [weak self] _, error in
            if let error = error {
                print("SpotifyManager: Error subscribing to player state: \(error)")
            } else {
                print("SpotifyManager: Successfully subscribed to player state")
            }
        })
        
        // Set ourselves as the player state delegate to receive track change notifications
        appRemote.playerAPI?.delegate = self
        print("SpotifyManager: Set as player state delegate")
        
        // Get current player state
        appRemote.playerAPI?.getPlayerState { [weak self] state, error in
            if let error = error {
                print("SpotifyManager: Error getting player state: \(error)")
            } else {
                print("SpotifyManager: Got initial player state successfully")
                self?.getCurrentTrack()
            }
        }
        
        // Start connection maintenance
        startConnectionMaintenance()
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("SpotifyManager: 🔌 Disconnected: Connection terminated - but keeping credentials for auto-reconnect")
        print("SpotifyManager: Disconnect error: \(error?.localizedDescription ?? "none")")
        
        DispatchQueue.main.async {
            self.isConnected = false
            // DON'T clear connectionStatus, currentTrack, or isPlaying - keep them as-is
            // This makes it behave like Apple Music where disconnection doesn't mean "logged out"
            if self.hasSpotifyCredentials {
                self.connectionStatus = "Ready (reconnecting...)"
            } else {
                self.connectionStatus = "Disconnected"
            self.currentTrack = nil
                self.isPlaying = false
            }
        }
        
        // Stop current connection maintenance timer
        stopConnectionMaintenance()
        
        // If we have credentials, AGGRESSIVELY attempt reconnection like Apple Music
        if getSavedAccessToken() != nil {
            print("SpotifyManager: Found saved token from \(UserDefaults.standard.object(forKey: "SpotifyTokenSaveDate") as? Date ?? Date()) - will attempt to use it")
            print("SpotifyManager: Spotify installed: \(checkSpotifyInstalled())")
            print("SpotifyManager: Starting PERSISTENT reconnection attempts")
            
            // Start immediate and persistent reconnection attempts
            startPersistentReconnection()
        }
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("SpotifyManager: ❌ Connection failed: \(error?.localizedDescription ?? "Unknown error")")
        
        // If we have credentials, keep trying persistently (don't give up like Apple Music)
        if getSavedAccessToken() != nil {
            print("SpotifyManager: Found saved token from \(UserDefaults.standard.object(forKey: "SpotifyTokenSaveDate") as? Date ?? Date()) - will attempt to use it")
            print("SpotifyManager: Will keep trying to reconnect (have credentials)")
            
            // Start persistent reconnection if not already running
            if reconnectionTimer == nil {
                startPersistentReconnection()
            }
        } else {
            DispatchQueue.main.async {
                self.connectionStatus = "Connection failed"
            }
        }
    }
    
    // MARK: - Playback Controls
    
    func togglePlayback() {
        guard appRemote.isConnected else {
            print("SpotifyManager: Cannot toggle playback - not connected")
            return
        }
        
        print("SpotifyManager: Toggling playback - current state: \(isPlaying ? "playing" : "paused")")
        
        if isPlaying {
            appRemote.playerAPI?.pause { [weak self] result, error in
                if let error = error {
                    print("SpotifyManager: Error pausing: \(error)")
                } else {
                    print("SpotifyManager: Successfully paused")
                    DispatchQueue.main.async {
                        self?.isPlaying = false
                    }
                }
            }
        } else {
            appRemote.playerAPI?.resume { [weak self] result, error in
                if let error = error {
                    print("SpotifyManager: Error resuming: \(error)")
                } else {
                    print("SpotifyManager: Successfully resumed")
                    DispatchQueue.main.async {
                        self?.isPlaying = true
                    }
                }
            }
        }
    }
    
    func skipToNextTrack() {
        guard appRemote.isConnected else {
            print("SpotifyManager: Cannot skip - not connected")
            return
        }
        
        print("SpotifyManager: Skipping to next track")
        appRemote.playerAPI?.skip(toNext: { result, error in
            if let error = error {
                print("SpotifyManager: Error skipping to next: \(error)")
            } else {
                print("SpotifyManager: Successfully skipped to next")
            }
        })
    }
    
    func skipToPreviousTrack() {
        guard appRemote.isConnected else {
            print("SpotifyManager: Cannot skip back - not connected")
            return
        }
        
        print("SpotifyManager: Skipping to previous track")
        appRemote.playerAPI?.skip(toPrevious: { result, error in
            if let error = error {
                print("SpotifyManager: Error skipping to previous: \(error)")
            } else {
                print("SpotifyManager: Successfully skipped to previous")
            }
        })
    }
    
    // MARK: - SPTAppRemotePlayerStateDelegate
    
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        print("SpotifyManager: 🎵 Player state changed - track: \(playerState.track.name), playing: \(!playerState.isPaused)")
        
        // Update playing state immediately
        DispatchQueue.main.async {
            self.isPlaying = !playerState.isPaused
        }
        
        updateCurrentTrack(from: playerState)
    }
    
    // MARK: - Token Persistence
    
    private func saveAccessToken(_ token: String) {
        UserDefaults.standard.set(token, forKey: "SpotifyAccessToken")
        UserDefaults.standard.set(Date(), forKey: "SpotifyTokenSaveDate")
        UserDefaults.standard.synchronize()
        print("SpotifyManager: Access token saved with timestamp")
    }
    
    private func getSavedAccessToken() -> String? {
        guard let token = UserDefaults.standard.string(forKey: "SpotifyAccessToken") else {
            print("SpotifyManager: No saved token found")
            return nil
        }
        
        // Check if we have a save date to determine token freshness
        if let saveDate = UserDefaults.standard.object(forKey: "SpotifyTokenSaveDate") as? Date {
            // Spotify tokens last 1 hour, but let's be more lenient and only expire after 6 hours
            // This way we only clear tokens when they're definitely expired, not proactively
            let sixHoursAgo = Date().addingTimeInterval(-21600) // 6 hours = 21600 seconds
            if saveDate < sixHoursAgo {
                print("SpotifyManager: Saved token is very old (>6 hours), will attempt use but may need refresh")
                // Don't clear the token automatically - let the API tell us if it's invalid
            }
            print("SpotifyManager: Found saved token from \(saveDate) - will attempt to use it")
        } else {
            print("SpotifyManager: Found token without save date (legacy), will attempt to use it")
        }
        
        return token
    }
    
    private func clearSavedToken() {
        UserDefaults.standard.removeObject(forKey: "SpotifyAccessToken")
        UserDefaults.standard.removeObject(forKey: "SpotifyTokenSaveDate")
        UserDefaults.standard.synchronize()
        print("SpotifyManager: Access token and save date cleared")
    }
    
    private func restoreConnection() {
        guard checkSpotifyInstalled() else {
            print("SpotifyManager: Spotify not installed, skipping restore")
            return
        }
        
        if let savedToken = getSavedAccessToken() {
            print("SpotifyManager: Setting up for session restoration with saved token")
            appRemote.connectionParameters.accessToken = savedToken
            
            // Automatically attempt connection like Apple Music
            print("SpotifyManager: Token set, attempting automatic reconnection")
            
            // Try to connect automatically in the background
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !self.appRemote.isConnected {
                    print("SpotifyManager: Attempting background reconnection with saved credentials")
                    self.attemptConnection(retryCount: 2)
                }
            }
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
                self.attemptConnectionWithFallback(retryCount: 5) // Increased retry and use fallback
            }
        } else {
            print("SpotifyManager: No saved token for reconnection")
        }
    }
    
    // Simplified connection method - just authorize when user wants to connect
    func connectWithPersistence() {
        print("SpotifyManager: 🔄 User requested Spotify connection")
        
        // If already connected, just get the current track
        guard !appRemote.isConnected else {
            print("SpotifyManager: Already connected, just refreshing track")
            getCurrentTrack()
            return
        }
        
        DispatchQueue.main.async {
            self.connectionStatus = "Launching Spotify..."
        }
        
        // First launch Spotify to ensure it's ready
        launchSpotifyIfNeeded {
            // Then try to connect with existing token if available
            if let savedToken = self.getSavedAccessToken() {
                print("SpotifyManager: Trying connection with saved token")
                self.appRemote.connectionParameters.accessToken = savedToken
                
                DispatchQueue.main.async {
                    self.connectionStatus = "Connecting..."
                }
                
                // Try to connect with retries
                self.attemptConnectionWithRetries(maxAttempts: 5) { success in
                    if !success {
                        print("SpotifyManager: Token connection failed, starting authorization")
                        self.startFreshAuthorization()
                    }
                }
            } else {
                print("SpotifyManager: No saved token, starting authorization")
                self.startFreshAuthorization()
            }
        }
    }
    
    // New method for connection with smart retries
    private func attemptConnectionWithRetries(maxAttempts: Int, completion: @escaping (Bool) -> Void) {
        var attempts = 0
        
        func tryConnect() {
            attempts += 1
            print("SpotifyManager: Connection attempt \(attempts)/\(maxAttempts)")
            
            // Try to connect
            self.appRemote.connect()
            
            // Check after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                if self.appRemote.isConnected {
                    print("SpotifyManager: ✅ Connected successfully on attempt \(attempts)")
                    completion(true)
                } else if attempts < maxAttempts {
                    // Exponential backoff - wait longer between retries
                    let delay = Double(attempts) * 0.5
                    print("SpotifyManager: Connection failed, retrying in \(delay)s...")
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        tryConnect()
                    }
                } else {
                    print("SpotifyManager: ❌ Failed to connect after \(maxAttempts) attempts")
                    completion(false)
                }
            }
        }
        
        tryConnect()
    }
    
    private func startFreshAuthorization() {
        DispatchQueue.main.async {
            self.connectionStatus = "Authorizing with Spotify..."
        }
        
        // Use a custom authorization approach instead of the potentially broken SDK method
        self.startCustomAuthorization()
    }
    
    private func startCustomAuthorization() {
        // Go back to using the SDK's built-in authorization - it's more reliable
        print("SpotifyManager: Using SDK authorization method")
        
        // Set up the configuration properly first
        let configuration = SPTConfiguration(clientID: "9b3615b5699e4b8d8da6222ebef7a99c", redirectURL: URL(string: "beatroo://spotify-callback")!)
        configuration.tokenSwapURL = nil
        configuration.tokenRefreshURL = nil
        
        // Use the SDK's authorize method with proper scope
        appRemote.authorizeAndPlayURI("")
    }
    
    private func tryAuthorizationUrls(urls: [String], index: Int) {
        guard index < urls.count else {
            print("SpotifyManager: All authorization methods failed, falling back to SDK method")
            DispatchQueue.main.async {
                self.connectionStatus = "Authorization failed - please ensure Spotify is installed"
            }
            // Last resort: try the original SDK method
            self.appRemote.authorizeAndPlayURI("")
            return
        }
        
        let urlString = urls[index]
        print("SpotifyManager: Trying authorization method \(index + 1): \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("SpotifyManager: Invalid URL, trying next method")
            tryAuthorizationUrls(urls: urls, index: index + 1)
            return
        }
        
        DispatchQueue.main.async {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    print("SpotifyManager: ✅ Authorization URL opened successfully with method \(index + 1)")
                } else {
                    print("SpotifyManager: ❌ Failed to open authorization URL with method \(index + 1), trying next...")
                    self.tryAuthorizationUrls(urls: urls, index: index + 1)
                }
            }
        }
    }
    
    // Public method to force fresh authorization (when token is expired)
    func forceReauthorization() {
        print("SpotifyManager: 🔄 FORCING FRESH AUTHORIZATION WITH PROPER SCOPES")
        
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
        
        // Start fresh authorization flow with proper scopes
        let scopeString = "app-remote-control,user-read-playback-state"
        print("SpotifyManager: Requesting authorization with scopes: \(scopeString)")
        
        // Build authorization URL manually to ensure proper scopes
        let authURLString = "spotify-action://authorize?" +
            "response_type=token&" +
            "client_id=\(clientID)&" +
            "redirect_uri=\(redirectURI.absoluteString)&" +
            "scope=\(scopeString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? scopeString)"
        
        launchSpotifyIfNeeded {
            if let authURL = URL(string: authURLString) {
                print("SpotifyManager: Opening auth URL with proper scopes")
                UIApplication.shared.open(authURL, options: [:]) { success in
                    if !success {
                        print("SpotifyManager: Failed to open authorization URL, falling back to SDK method")
                        self.appRemote.authorizeAndPlayURI("")
                    }
                }
            } else {
                print("SpotifyManager: Invalid auth URL, using SDK authorization")
                self.appRemote.authorizeAndPlayURI("")
            }
        }
    }
    
    // Check if Spotify app is actively running (not just installed)
    func isSpotifyRunning() -> Bool {
        // This is a simplified check - in reality, we can't directly check if another app is running
        // But we can check if we can establish a connection
        return appRemote.isConnected
    }
    
    // MARK: - Session Persistence
    
    // MARK: - Connection State Management
    
    private func startConnectionMaintenance() {
        // Stop any existing timer
        connectionMaintenanceTimer?.invalidate()
        
        // Start a timer to maintain connection every 30 seconds
        connectionMaintenanceTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.maintainConnection()
        }
        
        print("SpotifyManager: Started connection maintenance timer")
    }
    
    private func stopConnectionMaintenance() {
        connectionMaintenanceTimer?.invalidate()
        connectionMaintenanceTimer = nil
        print("SpotifyManager: Stopped connection maintenance timer")
    }
    
    func maintainConnection() {
        // Called periodically to ensure connection stays alive
        guard getSavedAccessToken() != nil else { 
            print("SpotifyManager: No saved token available for maintenance")
            return 
        }
        
        // If not connected but we have a token, start persistent reconnection
        if !isConnected && checkSpotifyInstalled() {
            print("SpotifyManager: Connection maintenance - starting persistent reconnection")
            startPersistentReconnection()
            return
        }
        
        // If connected, do a lightweight check
        if isConnected {
            // Simply check if we can get player state without forcing any changes
            appRemote.playerAPI?.getPlayerState { [weak self] result, error in
                if let error = error {
                    let errorMsg = error.localizedDescription
                    print("SpotifyManager: Connection maintenance check - error: \(errorMsg)")
                    
                    // On any error, start persistent reconnection but keep credentials
                    print("SpotifyManager: Connection maintenance failed - starting persistent reconnection")
                    self?.startPersistentReconnection()
                    
                    DispatchQueue.main.async {
                        self?.isConnected = false
                        self?.connectionStatus = "Reconnecting..."
                    }
                } else {
                    // Connection is healthy
                    print("SpotifyManager: Connection maintenance - healthy")
                    DispatchQueue.main.async {
                        self?.connectionStatus = "Connected"
                        self?.isConnected = true
                    }
                }
            }
        }
    }
    
    // MARK: - Persistent Connection Management
    private func startPersistentReconnection() {
        print("SpotifyManager: Starting persistent reconnection system")
        reconnectionAttempts = 0
        
        // Stop any existing timer
        reconnectionTimer?.invalidate()
        
        // Start persistent reconnection timer - try every 5 seconds
        reconnectionTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.attemptPersistentReconnection()
        }
    }
    
    private func attemptPersistentReconnection() {
        guard getSavedAccessToken() != nil else {
            print("SpotifyManager: No credentials for persistent reconnection")
            stopPersistentReconnection()
            return
        }
        
        guard !isConnected else {
            print("SpotifyManager: Already connected, stopping persistent reconnection")
            stopPersistentReconnection()
            return
        }
        
        guard checkSpotifyInstalled() else {
            print("SpotifyManager: Spotify not installed, will keep trying...")
            return
        }
        
        reconnectionAttempts += 1
        print("SpotifyManager: Persistent reconnection attempt #\(reconnectionAttempts)")
        
        // Don't try forever - after 10 attempts, slow down
        if reconnectionAttempts > 10 {
            print("SpotifyManager: Many failed attempts, slowing down reconnection")
            stopPersistentReconnection()
            
            // Restart with longer interval (30 seconds)
            reconnectionTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                self?.attemptPersistentReconnection()
            }
            reconnectionAttempts = 0
            return
        }
        
        // Try to connect without launching Spotify (to avoid annoying the user)
        appRemote.connect()
        
        // Check result after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if !self.isConnected {
                print("SpotifyManager: Connection failed, Spotify might not be running")
                // Don't launch Spotify automatically - it's annoying for users
                // Just update status to inform user
                DispatchQueue.main.async {
                    self.connectionStatus = "Spotify not running"
                }
            }
        }
    }
    
    private func stopPersistentReconnection() {
        print("SpotifyManager: Stopping persistent reconnection")
        reconnectionTimer?.invalidate()
        reconnectionTimer = nil
        reconnectionAttempts = 0
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