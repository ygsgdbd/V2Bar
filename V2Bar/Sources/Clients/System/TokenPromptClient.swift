import AppKit
import ComposableArchitecture

struct TokenPromptClient: Sendable {
    var prompt: @MainActor @Sendable (_ existingToken: String?) -> String?
    var showError: @MainActor @Sendable (_ message: String) -> Void
}

extension TokenPromptClient: DependencyKey {
    static let liveValue = Self(
        prompt: { existingToken in
            let alert = NSAlert()
            alert.messageText = "设置访问令牌"
            alert.informativeText = "请输入您的 V2EX 访问令牌"

            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
            input.placeholderString = "请输入访问令牌"
            if let existingToken {
                input.stringValue = existingToken
                input.selectText(nil)
            }

            alert.accessoryView = input
            alert.addButton(withTitle: "确定")
            alert.addButton(withTitle: "取消")

            guard alert.runModal() == .alertFirstButtonReturn else {
                return nil
            }

            let token = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return token.isEmpty ? nil : token
        },
        showError: { message in
            let alert = NSAlert()
            alert.messageText = "设置失败"
            alert.informativeText = message
            alert.alertStyle = .critical
            alert.addButton(withTitle: "确定")
            alert.runModal()
        }
    )

    static let testValue = noop

    static let noop = Self(
        prompt: { _ in nil },
        showError: { _ in }
    )
}

extension DependencyValues {
    var tokenPromptClient: TokenPromptClient {
        get { self[TokenPromptClient.self] }
        set { self[TokenPromptClient.self] = newValue }
    }
}
