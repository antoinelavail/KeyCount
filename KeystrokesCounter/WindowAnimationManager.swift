import SwiftUI
import Combine

// Define a custom notification name
extension Notification.Name {
    static let windowTransitionNearing = Notification.Name("windowTransitionNearing")
}

class WindowAnimationManager: ObservableObject {
    @Published var startComponentAnimations = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Listen for the notification from AppDelegate
        NotificationCenter.default.publisher(for: .windowTransitionNearing)
            .receive(on: RunLoop.main) // Ensure we're on the main thread
            .sink { [weak self] _ in
                self?.triggerComponentAnimations()
            }
            .store(in: &cancellables)
    }
    
    func triggerComponentAnimations() {
        // Use main thread directly with no delay
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.15)) { // Faster animation
                self.startComponentAnimations = true
            }
        }
    }
}

// Simpler animation modifier - translation only
struct SlideInAnimation: ViewModifier {
    @EnvironmentObject var animationManager: WindowAnimationManager
    let index: Int
    let baseDelay: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(animationManager.startComponentAnimations ? 1 : 0)
            .offset(x: animationManager.startComponentAnimations ? 0 : 15) // Only horizontal movement
            .animation(
                .easeOut(duration: 0.2).delay(baseDelay + Double(index) * 0.02), // Shorter delay between items
                value: animationManager.startComponentAnimations
            )
    }
}

extension View {
    func slideInAnimation(index: Int, baseDelay: Double = 0.0) -> some View {
        self.modifier(SlideInAnimation(index: index, baseDelay: baseDelay))
    }
}
