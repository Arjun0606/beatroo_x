import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject var socialMusicManager: SocialMusicManager
    @State private var selectedTab = 0
    
    private let beatrooPink = Color(hex: "B01E68")
    
    var unreadNotifications: [MusicNotification] {
        socialMusicManager.notifications.filter { !$0.isRead }
    }
    
    var likeNotifications: [MusicNotification] {
        socialMusicManager.notifications.filter { $0.type == .musicLike }
    }
    
    var playNotifications: [MusicNotification] {
        socialMusicManager.notifications.filter { $0.type == .musicPlay }
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Notifications")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    if !unreadNotifications.isEmpty {
                        Text("\(unreadNotifications.count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(beatrooPink)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Tab Selector
                HStack(spacing: 0) {
                    ForEach(0..<3) { index in
                        Button(action: { selectedTab = index }) {
                            VStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: tabIcon(for: index))
                                        .font(.system(size: 16))
                                    Text(tabTitle(for: index))
                                        .font(.system(size: 16, weight: .medium))
                                }
                                .foregroundColor(selectedTab == index ? beatrooPink : .gray)
                                
                                Rectangle()
                                    .fill(selectedTab == index ? beatrooPink : Color.clear)
                                    .frame(height: 2)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Content
                if socialMusicManager.notifications.isEmpty {
                    EmptyNotificationsView()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredNotifications()) { notification in
                                NotificationCard(notification: notification)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "bell.fill"
        case 1: return "heart.fill"
        case 2: return "play.fill"
        default: return "bell.fill"
        }
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "All"
        case 1: return "Vibes"
        case 2: return "Plays"
        default: return "All"
        }
    }
    
    private func filteredNotifications() -> [MusicNotification] {
        switch selectedTab {
        case 1: return likeNotifications
        case 2: return playNotifications
        default: return socialMusicManager.notifications
        }
    }
}

struct EmptyNotificationsView: View {
    private let beatrooPink = Color(hex: "B01E68")
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "bell.slash.fill")
                .font(.system(size: 60))
                .foregroundColor(beatrooPink.opacity(0.6))
            
            VStack(spacing: 12) {
                Text("No Notifications")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text("Start sharing your music taste and discover what others are listening to nearby!")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
}

struct NotificationCard: View {
    let notification: MusicNotification
    private let beatrooPink = Color(hex: "B01E68")
    
    private var notificationColor: Color {
        switch notification.type {
        case .musicLike: return .red
        case .musicPlay: return .green
        }
    }
    
    private var notificationIcon: String {
        switch notification.type {
        case .musicLike: return "heart.fill"
        case .musicPlay: return "play.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: notificationIcon)
                .font(.system(size: 20))
                .foregroundColor(notificationColor)
                .frame(width: 40, height: 40)
                .background(notificationColor.opacity(0.2))
                .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(notification.message)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                Text("\(notification.trackTitle) by \(notification.trackArtist)")
                    .font(.system(size: 14))
                    .foregroundColor(beatrooPink)
                    .lineLimit(1)
                
                Text(timeAgoString(from: notification.timestamp))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Unread indicator
            if !notification.isRead {
                Circle()
                    .fill(beatrooPink)
                    .frame(width: 8, height: 8)
            }
        }
        .padding()
        .background(
            Color.gray.opacity(notification.isRead ? 0.05 : 0.1)
        )
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    notification.isRead ? Color.clear : beatrooPink.opacity(0.3),
                    lineWidth: notification.isRead ? 0 : 1
                )
        )
    }
    
    private func timeAgoString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
} 