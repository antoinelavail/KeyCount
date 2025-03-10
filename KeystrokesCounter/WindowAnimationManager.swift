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
            .sink { [weak self] _ in
                self?.triggerComponentAnimations()
            }
            .store(in: &cancellables)
    }
    
    func triggerComponentAnimations() {
        withAnimation {
            startComponentAnimations = true
        }
    }
}

// ViewModifier for staggered animations with bounce
struct StaggeredBounceAnimation: ViewModifier {
    @EnvironmentObject var animationManager: WindowAnimationManager
    let index: Int
    let baseDelay: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(animationManager.startComponentAnimations ? 1 : 0)
            .scaleEffect(animationManager.startComponentAnimations ? 1.0 : 0.92)
            .offset(x: animationManager.startComponentAnimations ? 0 : 20)
            .animation(
                .spring(
                    response: 0.6, 
                    dampingFraction: 0.65, 
                    blendDuration: 0.1
                )
                .delay(baseDelay + Double(index) * 0.05),
                value: animationManager.startComponentAnimations
            )
    }
}

extension View {
    func staggeredBounceAnimation(index: Int, baseDelay: Double = 0.0) -> some View {
        self.modifier(StaggeredBounceAnimation(index: index, baseDelay: baseDelay))
    }
}
