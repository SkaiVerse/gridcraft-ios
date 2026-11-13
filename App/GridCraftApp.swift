import SwiftUI

@main
struct GridCraftApp: App {
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color(red: 0.11, green: 0.11, blue: 0.12).ignoresSafeArea()
                WebHost()
            }
            .statusBarHidden(true)
        }
    }
}

struct WebHost: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> WebViewController { WebViewController() }
    func updateUIViewController(_ vc: WebViewController, context: Context) {}
}
