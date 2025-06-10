import SwiftUI
import FirebaseFirestore

struct ShareableStatsView: View {
    let userStats: UserStats
    let rank: Int
    let totalUsers: Int
    let city: String
    @Binding var isPresented: Bool
    
    @State private var likesGiven: Int = 0
    @State private var playsGiven: Int = 0
    
    private let beatrooPink = Color(hex: "B01E68")
    private let cardWidth: CGFloat = 320
    private let cardHeight: CGFloat = 400
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }
            
            VStack(spacing: 20) {
                // Stats Card
                VStack(spacing: 0) {
                    statsCard
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                        .cornerRadius(20)
                        .shadow(color: beatrooPink.opacity(0.3), radius: 20, x: 0, y: 10)
                }
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button(action: shareToStory) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 16))
                            Text("Share")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(beatrooPink)
                        .cornerRadius(25)
                    }
                    
                    Button(action: saveToPhotos) {
                        HStack(spacing: 8) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 16))
                            Text("Save")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(beatrooPink)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(25)
                    }
                }
            }
        }
        .onAppear {
            loadUserInteractionStats()
        }
    }
    
    private var statsCard: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.black,
                    beatrooPink.opacity(0.3),
                    Color.black
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Animated background elements
            ForEach(0..<15, id: \.self) { index in
                Circle()
                    .fill(beatrooPink.opacity(0.1))
                    .frame(width: CGFloat.random(in: 20...60))
                    .position(
                        x: CGFloat.random(in: 0...cardWidth),
                        y: CGFloat.random(in: 0...cardHeight)
                    )
                    .animation(
                        Animation.easeInOut(duration: 2.0)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: index
                    )
            }
            
            // Content
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("BEATROO")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(beatrooPink)
                    
                    Text("Music Discovery Stats")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Main Rank Display
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [beatrooPink, Color.orange, beatrooPink],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                            .frame(width: 100, height: 100)
                        
                        VStack(spacing: 4) {
                            Text("#\(rank)")
                                .font(.system(size: 32, weight: .black))
                                .foregroundColor(.white)
                            
                            Text("RANK")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    VStack(spacing: 4) {
                        Text(rankDescription)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                        
                        Text("in \(city)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                }
                
                // Stats Grid
                HStack(spacing: 20) {
                    StatItem(
                        icon: "music.note",
                        value: String(format: "%.1f", userStats.totalScore),
                        label: "POINTS",
                        color: beatrooPink
                    )
                    
                    StatItem(
                        icon: "heart.fill",
                        value: "\(likesGiven)",
                        label: "LIKES",
                        color: .red
                    )
                    
                    StatItem(
                        icon: "play.fill",
                        value: "\(playsGiven)",
                        label: "PLAYS",
                        color: .green
                    )
                }
                
                // Footer
                VStack(spacing: 4) {
                    Text("Join the vibe")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)
                    
                    Text("@beatroo_app")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(beatrooPink)
                }
            }
            .padding(24)
        }
    }
    
    private var rankDescription: String {
        switch rank {
        case 1: return "🥇"
        case 2: return "🥈"
        case 3: return "🥉"
        case 4: return "👑"
        case 5: return "🔥"
        case 6: return "⚡"
        case 7: return "💎"
        case 8: return "⭐"
        case 9: return "🎵"
        case 10: return "🎶"
        default: return "🎧"
        }
    }
    
    private func loadUserInteractionStats() {
        guard !userStats.userId.isEmpty else {
            likesGiven = 0
            playsGiven = 0
            return
        }
        
        Task {
            do {
                // Load likes given by this user
                let likesSnapshot = try await Firestore.firestore()
                    .collection("music_likes")
                    .whereField("fromUserId", isEqualTo: userStats.userId)
                    .getDocuments()
                
                // Load plays by this user
                let playsSnapshot = try await Firestore.firestore()
                    .collection("music_plays")
                    .whereField("fromUserId", isEqualTo: userStats.userId)
                    .getDocuments()
                
                await MainActor.run {
                    self.likesGiven = likesSnapshot.documents.count
                    self.playsGiven = playsSnapshot.documents.count
                }
                
            } catch {
                print("Error loading interaction stats: \(error)")
                await MainActor.run {
                    self.likesGiven = 0
                    self.playsGiven = 0
                }
            }
        }
    }
    
    private func shareToStory() {
        let image = generateStatsImage()
        
        // Create more specific sharing options
        let shareText = "Check out my Beatroo music discovery stats! 🎵 Rank #\(rank) in \(city) with \(String(format: "%.1f", userStats.totalScore)) points!"
        
        let activityVC = UIActivityViewController(
            activityItems: [shareText, image],
            applicationActivities: nil
        )
        
        // Customize for better social media sharing
        activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if completed {
                print("Successfully shared to: \(activityType?.rawValue ?? "unknown")")
            }
        }
        
        // Configure for iPad
        if let popover = activityVC.popoverPresentationController {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
        }
        
        // Present the share sheet using the modern approach
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            // Get the key window for this scene
            let keyWindow = windowScene.windows.first { $0.isKeyWindow }
            
            if let window = keyWindow ?? windowScene.windows.first,
               let rootViewController = window.rootViewController {
                
                // Find the topmost view controller
                var topViewController = rootViewController
                while let presented = topViewController.presentedViewController {
                    topViewController = presented
                }
                
                topViewController.present(activityVC, animated: true)
            }
        }
    }
    
    private func saveToPhotos() {
        let image = generateStatsImage()
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        // Show feedback (you could add a toast notification here)
        print("Stats image saved to Photos")
    }
    
    private func generateStatsImage() -> UIImage {
        let renderer = ImageRenderer(content: statsCard.frame(width: cardWidth, height: cardHeight))
        renderer.scale = 3.0 // High resolution for crisp sharing
        return renderer.uiImage ?? UIImage()
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(color)
            }
            
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
    }
}

// MARK: - Preview
struct ShareableStatsView_Previews: PreviewProvider {
    static var previews: some View {
        ShareableStatsView(
            userStats: UserStats(
                userId: "preview",
                totalScore: 47.5,
                lastUpdated: Date(),
                city: "San Francisco"
            ),
            rank: 3,
            totalUsers: 150,
            city: "San Francisco",
            isPresented: .constant(true)
        )
    }
} 