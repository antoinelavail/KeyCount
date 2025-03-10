import SwiftUI

struct SlideTransition: ViewModifier {
    let index: Int
    let value: Any
    
    func body(content: Content) -> some View {
        content
            .transition(.asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
            ))
            .animation(
                .spring(response: 0.3, dampingFraction: 0.7)
                    .delay(Double(index) * 0.03),
                value: value
            )
    }
}

extension View {
    func slideTransition(index: Int, value: Any) -> some View {
        self.modifier(SlideTransition(index: index, value: value))
    }
}
