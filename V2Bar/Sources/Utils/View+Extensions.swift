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

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        modifier(CursorModifier(cursor: cursor))
    }
    
    var pointingCursor: some View {
        cursor(.pointingHand)
    }
} 