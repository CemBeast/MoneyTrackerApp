import SwiftUI

struct RootTabView: View {
    @State private var selectedTab = 0
    
    init() {
        // Configure tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.cyberBlack)
        
        // Normal state
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.white.opacity(0.5))
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(Color.white.opacity(0.5))
        ]
        
        // Selected state
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.neonGreen)
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(Color.neonGreen)
        ]
        
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        
        // Configure navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color.cyberBlack)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.neonGreen)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.neonGreen)]
        
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(Color.neonGreen)
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            LogView()
                .tabItem {
                    Label("Log", systemImage: "list.bullet.rectangle")
                }
                .tag(0)

            MonthsView()
                .tabItem {
                    Label("Months", systemImage: "calendar")
                }
                .tag(1)

            CategoriesView()
                .tabItem {
                    Label("Categories", systemImage: "square.grid.2x2")
                }
                .tag(2)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.pie.fill")
                }
                .tag(3)

            BackupView()
                .tabItem {
                    Label("Backup", systemImage: "externaldrive")
                }
                .tag(4)
        }
        .tint(.neonGreen)
    }
}
