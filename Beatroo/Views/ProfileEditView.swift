import SwiftUI
import PhotosUI

struct ProfileEditView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var displayName = ""
    @State private var username = ""
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isLoading = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    let beatrooPink = Color(red: 1.0, green: 0.0, blue: 0.4)
    
    var isFormValid: Bool {
        !displayName.isEmpty && !username.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 30) {
                        // Header
                        VStack(spacing: 10) {
                            Text("Edit Profile")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text("Update your profile information")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 20)
                        
                        // Profile Photo
                        VStack(spacing: 15) {
                            Button(action: { showImagePicker = true }) {
                                if let image = selectedImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(beatrooPink, lineWidth: 3)
                                        )
                                } else if let user = authManager.currentUser,
                                          let photoURL = user.photoURL,
                                          let url = URL(string: photoURL) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                    } placeholder: {
                                        ProgressView()
                                            .tint(beatrooPink)
                                    }
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(beatrooPink, lineWidth: 3)
                                    )
                                } else {
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 120, height: 120)
                                        
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            
                            Text("Tap to change photo")
                                .font(.system(size: 14))
                                .foregroundColor(beatrooPink)
                        }
                        
                        // Form Fields
                        VStack(spacing: 20) {
                            // Display Name
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Display Name")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                TextField("Enter your display name", text: $displayName)
                                    .textFieldStyle(CustomTextFieldStyle())
                            }
                            
                            // Username
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Username")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                
                                TextField("Choose a unique username", text: $username)
                                    .textFieldStyle(CustomTextFieldStyle())
                                    .autocapitalization(.none)
                            }
                        }
                        .padding(.horizontal, 40)
                        
                        // Save Button
                        Button(action: saveChanges) {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Save Changes")
                                    .font(.system(size: 18, weight: .semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(isFormValid ? beatrooPink : Color.gray.opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(28)
                        .disabled(!isFormValid || isLoading)
                        .padding(.horizontal, 40)
                        .padding(.top, 20)
                        
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(beatrooPink)
                }
            }
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            loadCurrentUserData()
        }
    }
    
    private func loadCurrentUserData() {
        guard let user = authManager.currentUser else { return }
        displayName = user.displayName
        username = user.username
    }
    
    private func saveChanges() {
        guard var user = authManager.currentUser else { return }
        
        isLoading = true
        
        Task {
            do {
                // Upload new profile photo if one was selected
                if let image = selectedImage {
                    let photoURL = try await authManager.uploadProfilePhoto(image)
                    user.photoURL = photoURL
                }
                
                // Update user data
                user.displayName = displayName
                user.username = username
                
                // Save to Firestore
                try await authManager.updateUserProfile(user)
                
                // Dismiss the view
                await MainActor.run {
                    dismiss()
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isLoading = false
                }
            }
        }
    }
} 