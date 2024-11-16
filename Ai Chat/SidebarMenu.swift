import SwiftUI

struct SidebarMenu: View {
    var onStartNewSession: () -> Void
    var onLoadSession: () -> Void
    var onShowSettings: () -> Void

    var body: some View {
        List {
            Button(action: onStartNewSession) {
                Label("Start New Session", systemImage: "plus.circle")
            }
            Button(action: onLoadSession) {
                Label("Load Session", systemImage: "tray.full")
            }
            Button(action: onShowSettings) {
                Label("Settings", systemImage: "gearshape")
            }
        }
        .listStyle(SidebarListStyle())
        .navigationTitle("Menu")
    }
}
