import SwiftUI

struct CursorModifier: ViewModifier {
    let cursor: NSCursor
    
    func body(content: Content) -> some View {
        content.onHover { inside in
            if inside {
                cursor.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

struct UsernameStyle: ViewModifier {
    @Binding var isHovered: Bool
    
    func body(content: Content) -> some View {
        content
            .fontWeight(.medium)
            .foregroundColor(.primary)
            .underline(isHovered)
    }
}

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        modifier(CursorModifier(cursor: cursor))
    }
    
    var pointingCursor: some View {
        cursor(.pointingHand)
    }
    
    func usernameStyle(isHovered: Binding<Bool>) -> some View {
        modifier(UsernameStyle(isHovered: isHovered))
    }
} 