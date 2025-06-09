import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import GoogleSignIn

enum AuthState {
    case loading
    case signedOut
    case needsProfile
    case needsPermissions
    case signedIn
}

@MainActor
class AuthenticationManager: ObservableObject {
    @Published var authState: AuthState = .loading
    @Published var currentUser: User?
    @Published var errorMessage: String?
    
    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    
    init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let handle = authStateHandle {
            auth.removeStateDidChangeListener(handle)
        }
    }
    
    private func setupAuthStateListener() {
        authStateHandle = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let firebaseUser = firebaseUser {
                    // User is signed in
                    await self.loadUserProfile(firebaseUser: firebaseUser)
                } else {
                    // User is signed out
                    self.currentUser = nil
                    self.authState = .signedOut
                }
            }
        }
    }
    
    private func loadUserProfile(firebaseUser: FirebaseAuth.User) async {
        do {
            let document = try await db.collection("users").document(firebaseUser.uid).getDocument()
            
            if document.exists,
               let user = try? document.data(as: User.self) {
                // User profile exists
                self.currentUser = user
                if user.isProfileComplete {
                    // Check if permissions setup is complete
                    let permissionsComplete = UserDefaults.standard.bool(forKey: "PermissionsSetupCompleted")
                    self.authState = permissionsComplete ? .signedIn : .needsPermissions
                } else {
                    self.authState = .needsProfile
                }
            } else {
                // Create new user profile
                let newUser = User.empty(uid: firebaseUser.uid, email: firebaseUser.email ?? "")
                self.currentUser = newUser
                self.authState = .needsProfile
            }
        } catch {
            print("Error loading user profile: \(error)")
            self.authState = .needsProfile
        }
    }
    
    // MARK: - Google Sign In
    func signInWithGoogle() async throws {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw NSError(domain: "BeatrooError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Missing Google client ID"])
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw NSError(domain: "BeatrooError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No root view controller found"])
        }
        
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
        
        guard let idToken = result.user.idToken?.tokenString else {
            throw NSError(domain: "BeatrooError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get ID token"])
        }
        
        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: result.user.accessToken.tokenString
        )
        
        let authResult = try await auth.signIn(with: credential)
        
        // Check if this is a new user
        if authResult.additionalUserInfo?.isNewUser == true {
            // Create initial user document
            var newUser = User.empty(uid: authResult.user.uid, email: authResult.user.email ?? "")
            newUser.googleId = result.user.userID
            
            // Pre-fill some data from Google
            if let googleProfile = result.user.profile {
                newUser.displayName = googleProfile.name
                newUser.photoURL = googleProfile.imageURL(withDimension: 200)?.absoluteString
            }
            
            try await saveUserProfile(newUser)
        }
    }
    
    // MARK: - Profile Management
    func saveUserProfile(_ user: User) async throws {
        var updatedUser = user
        updatedUser.updatedAt = Date()
        
        try await db.collection("users").document(user.uid).setData(
            try Firestore.Encoder().encode(updatedUser)
        )
        
        self.currentUser = updatedUser
        if updatedUser.isProfileComplete {
            // After profile completion, check if permissions are needed
            let permissionsComplete = UserDefaults.standard.bool(forKey: "PermissionsSetupCompleted")
            self.authState = permissionsComplete ? .signedIn : .needsPermissions
        }
    }
    
    func uploadProfilePhoto(_ image: UIImage) async throws -> String {
        guard let uid = currentUser?.uid else {
            throw NSError(domain: "BeatrooError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user ID found"])
        }
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "BeatrooError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        
        let storageRef = Storage.storage().reference()
        let photoRef = storageRef.child("profile_photos/\(uid).jpg")
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await photoRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await photoRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    // MARK: - Auth State Updates
    func updateAuthState() {
        guard let user = currentUser else { return }
        
        if user.isProfileComplete {
            let permissionsComplete = UserDefaults.standard.bool(forKey: "PermissionsSetupCompleted")
            self.authState = permissionsComplete ? .signedIn : .needsPermissions
        } else {
            self.authState = .needsProfile
        }
    }
    
    // MARK: - Account Management
    func signOut() {
        do {
            try auth.signOut()
            currentUser = nil
            authState = .signedOut
        } catch {
            print("Error signing out: \(error)")
        }
    }
    
    func deleteAccount() async throws {
        guard let user = auth.currentUser,
              let uid = currentUser?.uid else {
            throw NSError(domain: "BeatrooError", code: 0, userInfo: [NSLocalizedDescriptionKey: "No user found"])
        }
        
        // Delete user's profile photo from Storage if it exists
        if let photoURL = currentUser?.photoURL,
           photoURL.contains("profile_photos") {
            do {
                let storageRef = Storage.storage().reference(forURL: photoURL)
                try await storageRef.delete()
                print("Profile photo deleted from storage")
            } catch {
                print("Error deleting profile photo: \(error)")
                // Continue with account deletion even if photo deletion fails
            }
        }
        
        // Try to delete user document from Firestore (may fail due to security rules)
        do {
            try await db.collection("users").document(uid).delete()
            print("User document deleted from Firestore")
        } catch {
            print("Error deleting Firestore document (may be due to security rules): \(error)")
            // Continue with account deletion even if Firestore deletion fails
            // The document can be cleaned up later via server-side functions
        }
        
        // Delete the Firebase Auth account (this is the most important part)
        try await user.delete()
        print("Firebase Auth account deleted")
        
        // Update local state - this will trigger the auth state listener
        // and automatically redirect to sign out state
        currentUser = nil
        authState = .signedOut
        
        // Clear any local preferences
        UserDefaults.standard.removeObject(forKey: "PermissionsSetupCompleted")
        UserDefaults.standard.synchronize()
        
        print("Account deletion completed - user will be redirected to sign up")
    }
    
    func updateUserProfile(_ updatedUser: User) async throws {
        var userToSave = updatedUser
        userToSave.updatedAt = Date()
        
        try await db.collection("users").document(updatedUser.uid).setData(
            try Firestore.Encoder().encode(userToSave)
        )
        
        self.currentUser = userToSave
    }
} 