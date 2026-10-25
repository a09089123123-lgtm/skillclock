import SwiftUI

@main
@MainActor
struct SkillClockApp: App {
    @StateObject private var controller = MonitorController()

    var body: some Scene {
        WindowGroup {
            RootView(controller: controller)
        }
    }
}
