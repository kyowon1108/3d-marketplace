import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var authManager = AuthManager.shared
    @State private var selectedTab: Tab = .home
    @State private var unreadCount: Int = 0

    enum Tab {
        case home, browse, sell, inbox, profile
    }
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                mainTabView()
            } else {
                AuthenticationView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: authManager.isAuthenticated)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AuthExpired"))) { _ in
            authManager.logout()
            AppToast(message: "세션이 만료되었습니다. 다시 로그인해주세요.", style: .error)
        }
    }
    
    @ViewBuilder
    private func mainTabView() -> some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(Tab.home)
            
            ProductListView()
                .tabItem {
                    Label("Browse", systemImage: "magnifyingglass")
                }
                .tag(Tab.browse)
            
            SellNewView()
                .tabItem {
                    Label("Sell", systemImage: "plus.circle.fill")
                }
                .tag(Tab.sell)
            
            InboxView()
                .tabItem {
                    Label("Inbox", systemImage: "message.fill")
                }
                .tag(Tab.inbox)
                .badge(unreadCount)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
                .tag(Tab.profile)
        }
        .tint(Theme.Colors.violetAccent)
        .task {
            // Fetch unread count
            if let summary: UserSummaryResponse = try? await APIClient.shared.request(
                endpoint: "/me/summary"
            ) {
                unreadCount = summary.unread_messages
            }
        }
        .onAppear {
            let appearance = UITabBarAppearance()
            appearance.configureWithTransparentBackground()
            appearance.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
            
            UITabBar.appearance().standardAppearance = appearance
            if #available(iOS 15.0, *) {
                UITabBar.appearance().scrollEdgeAppearance = appearance
            }
        }
    }
}
