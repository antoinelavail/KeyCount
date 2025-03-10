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
        // Reset state before animation if needed
        if startComponentAnimations {
            startComponentAnimations = false
            
            // Small delay to ensure UI updates before animation starts
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                self.startAnimation()
            }
        } else {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Explicitly use the main thread
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) { // Use faster initial animation
                self.startComponentAnimations = true
            }
        }
    }
}

// ViewModifier for staggered animations with bounce - optimized for performance
struct StaggeredBounceAnimation: ViewModifier {
    @EnvironmentObject var animationManager: WindowAnimationManager
    let index: Int
    let baseDelay: Double
    
    func body(content: Content) -> some View {
        content
            .opacity(animationManager.startComponentAnimations ? 1 : 0)
            .scaleEffect(animationManager.startComponentAnimations ? 1.0 : 0.96) // Less scale difference
            .offset(x: animationManager.startComponentAnimations ? 0 : 12) // Smaller offset for quicker movement
            .animation(
                .spring(
                    response: 0.32, // Reduced for snappier response
                    dampingFraction: 0.72, // Increased for less bounce
                    blendDuration: 0.05 // Reduced blend time
                )
                .delay(baseDelay + Double(index) * 0.03), // Shorter delays between items
                value: animationManager.startComponentAnimations
            )
    }
}

extension View {
    func staggeredBounceAnimation(index: Int, baseDelay: Double = 0.0) -> some View {
        self.modifier(StaggeredBounceAnimation(index: index, baseDelay: baseDelay))
    }
}
