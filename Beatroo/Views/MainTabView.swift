import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var socialMusicManager: SocialMusicManager
    @EnvironmentObject var musicCoordinator: MusicServiceCoordinator
    @State private var selectedTab = 0
    
    private let beatrooPink = Color(hex: "B01E68") // Consistent Beatroo pink color
    
    private var notificationTabIcon: String {
        let unreadCount = socialMusicManager.notifications.filter { !$0.isRead }.count
        return unreadCount > 0 ? "bell.badge" : "bell"
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NowPlayingView()
                .tabItem {
                    Label("Now Playing", systemImage: "music.note")
                }
                .tag(0)
            
            LeaderboardView()
                .tabItem {
                    Label("Leaderboard", systemImage: "trophy")
                }
                .tag(1)
            
            NotificationsView()
                .tabItem {
                    Label("Notifications", systemImage: notificationTabIcon)
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
                .tag(3)
        }
        .accentColor(beatrooPink)
        .onAppear {
            // Initialize social music components
            if let userId = authManager.currentUser?.uid {
                socialMusicManager.initialize(userId: userId, musicCoordinator: musicCoordinator, locationManager: locationManager)
            }
            
            // Make tab bar more visible with a custom appearance
            let appearance = UITabBarAppearance()
            
            // Use a darker background for better visibility
            appearance.backgroundColor = UIColor.black
            
            // Make the icon and text more visible when selected
            let selected = UIColor(beatrooPink)
            appearance.stackedLayoutAppearance.selected.iconColor = selected
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selected]
            
            // Make unselected items more visible with light gray
            let unselected = UIColor.lightGray
            appearance.stackedLayoutAppearance.normal.iconColor = unselected
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: unselected]
            
            // Add a subtle top border
            appearance.shadowColor = UIColor(white: 0.3, alpha: 0.3)
            
            // Apply the appearance settings
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        .preferredColorScheme(.dark) // Force dark mode for consistent appearance
    }
} 