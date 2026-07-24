import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ShelfView()
                .tabItem {
                    Label("书架", systemImage: "books.vertical.fill")
                }

            SearchView()
                .tabItem {
                    Label("搜索", systemImage: "magnifyingglass")
                }

            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gear")
                }
        }
    }
}
