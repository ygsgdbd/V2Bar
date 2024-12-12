import SwiftUI
import AppKit

#if DEBUG
import Atlantis
#endif

@main
struct V2BarApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    
    init() {
        #if DEBUG
        Atlantis.start()
        #endif
    }
    
    var body: some Scene {
        MenuBarExtra {
            ContentView()
        } label: {
            Text("V2")
                .font(.custom("Futura", size: 12))
                .fontWeight(.medium)
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 监听键盘事件
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // ESC 键
                if let window = NSApplication.shared.windows.first(where: { $0.isKeyWindow }) {
                    window.close()
                    return nil // 事件已处理
                }
            }
            return event
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // 清理监听器
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
} 
