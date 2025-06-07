import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isSigningIn = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // Logo and Title
                VStack(spacing: 30) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 80))
                        .foregroundColor(Color("BeatrooPink"))
                    
                    VStack(spacing: 10) {
                        Text("Beatroo")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Discover music together")
                            .font(.system(size: 18))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                // Sign In Button
                VStack(spacing: 20) {
                    Button {
                        signInWithGoogle()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "globe")
                                .font(.system(size: 20))
                            
                            Text("Continue with Google")
                                .font(.system(size: 18, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color("BeatrooPink"))
                        .cornerRadius(28)
                    }
                    .disabled(isSigningIn)
                    .opacity(isSigningIn ? 0.7 : 1.0)
                    .padding(.horizontal, 40)
                    
                    if isSigningIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
                
                Spacer()
                
                // Footer
                VStack(spacing: 8) {
                    Text("By continuing, you agree to our")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Text("Terms of Service")
                            .font(.system(size: 12))
                            .foregroundColor(Color("BeatrooPink"))
                            .underline()
                        
                        Text("and")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                        
                        Text("Privacy Policy")
                            .font(.system(size: 12))
                            .foregroundColor(Color("BeatrooPink"))
                            .underline()
                    }
                }
                .padding(.bottom, 50)
            }
        }
        .alert("Sign In Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func signInWithGoogle() {
        isSigningIn = true
        
        Task {
            do {
                try await authManager.signInWithGoogle()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isSigningIn = false
        }
    }
} 