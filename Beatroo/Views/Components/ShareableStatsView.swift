import SwiftUI

struct ShareableStatsView: View {
    let userStats: UserStats
    let rank: Int
    let totalUsers: Int
    let city: String
    @Binding var isPresented: Bool
    
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
                        value: "\(userStats.likesGiven)",
                        label: "LIKES",
                        color: .red
                    )
                    
                    StatItem(
                        icon: "play.fill",
                        value: "\(userStats.playsGiven)",
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
        let percentage = (Double(totalUsers - rank + 1) / Double(totalUsers)) * 100
        
        switch rank {
        case 1:
            return "👑 MUSIC KING/QUEEN"
        case 2...5:
            return "🔥 TOP DISCOVERER"
        case 6...10:
            return "⚡ VIBE CURATOR"
        default:
            if percentage >= 80 {
                return "🎵 RISING STAR"
            } else if percentage >= 60 {
                return "🎧 MUSIC LOVER"
            } else {
                return "🎶 VIBE EXPLORER"
            }
        }
    }
    
    private func shareToStory() {
        let image = generateStatsImage()
        
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityVC, animated: true)
        }
    }
    
    private func saveToPhotos() {
        let image = generateStatsImage()
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    
    private func generateStatsImage() -> UIImage {
        let renderer = ImageRenderer(content: statsCard.frame(width: cardWidth, height: cardHeight))
        renderer.scale = 3.0 // High resolution
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

// MARK: - User Stats Extension
extension UserStats {
    var likesGiven: Int {
        // This would be tracked in Firebase, for now return a placeholder
        return Int.random(in: 5...50)
    }
    
    var playsGiven: Int {
        // This would be tracked in Firebase, for now return a placeholder  
        return Int.random(in: 2...25)
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