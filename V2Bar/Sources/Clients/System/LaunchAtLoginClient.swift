import ComposableArchitecture
import Foundation
import ServiceManagement

enum LaunchAtLoginStatus: Equatable, Sendable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable

    init(_ status: SMAppService.Status) {
        switch status {
        case .enabled:
            self = .enabled
        case .notRegistered:
            self = .disabled
        case .requiresApproval:
            self = .requiresApproval
        case .notFound:
            self = .unavailable
        @unknown default:
            self = .unavailable
        }
    }
}

struct LaunchAtLoginEnvironment {
    var serviceManagementStatus: () -> SMAppService.Status
    var legacyPlistStatus: (URL) -> SMAppService.Status
    var registerMainApp: () throws -> Void
    var unregisterMainApp: () async throws -> Void
    var plistURL: URL
    var executableURL: () -> URL?
    var runLaunchctl: ([String]) throws -> Void
    var userID: () -> uid_t
    var fileManager: FileManager
    var moveItemAt: (URL, URL) throws -> Void
    var removeItemAt: (URL) throws -> Void
    var replaceItemAt: (URL, URL) throws -> Void
}

struct LaunchAtLoginClient: Sendable {
    var status: @Sendable () async -> LaunchAtLoginStatus
    var setEnabled: @Sendable (Bool) async throws -> Void
}

extension LaunchAtLoginClient: DependencyKey {
    static let liveValue = Self(
        status: {
            status(environment: liveEnvironment)
        },
        setEnabled: { isEnabled in
            try await setEnabled(isEnabled, environment: liveEnvironment)
        }
    )

    static let testValue = noop

    static let noop = Self(
        status: { .unavailable },
        setEnabled: { _ in }
    )
}

extension DependencyValues {
    var launchAtLoginClient: LaunchAtLoginClient {
        get { self[LaunchAtLoginClient.self] }
        set { self[LaunchAtLoginClient.self] = newValue }
    }
}

extension LaunchAtLoginClient {
    private static let launchAgentIdentifier = "top.ygsgdbd.V2Bar"
    private static let launchAgentPlistName = "\(launchAgentIdentifier).plist"
    private static let launchAgentStagingDirectoryName = ".\(launchAgentIdentifier).staging"

    private static var liveEnvironment: LaunchAtLoginEnvironment {
        LaunchAtLoginEnvironment(
            serviceManagementStatus: { SMAppService.mainApp.status },
            legacyPlistStatus: { SMAppService.statusForLegacyPlist(at: $0) },
            registerMainApp: { try SMAppService.mainApp.register() },
            unregisterMainApp: { try await SMAppService.mainApp.unregister() },
            plistURL: FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
                .appendingPathComponent(launchAgentPlistName),
            executableURL: { Bundle.main.executableURL },
            runLaunchctl: runLaunchctl,
            userID: { getuid() },
            fileManager: .default,
            moveItemAt: { sourceURL, destinationURL in
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            },
            removeItemAt: { try FileManager.default.removeItem(at: $0) },
            replaceItemAt: { originalItemURL, newItemURL in
                _ = try FileManager.default.replaceItemAt(
                    originalItemURL,
                    withItemAt: newItemURL
                )
            }
        )
    }

    static func status(environment: LaunchAtLoginEnvironment) -> LaunchAtLoginStatus {
        let nativeStatus = environment.serviceManagementStatus()
        if nativeStatus == .enabled {
            if environment.fileManager.fileExists(atPath: environment.plistURL.path) {
                try? removeFallbackLaunchAgent(environment: environment)
            }
            return .enabled
        }

        let hasFallbackPlist = environment.fileManager.fileExists(atPath: environment.plistURL.path)
        let fallbackStatus = fallbackLaunchAgentStatus(environment: environment)
        if hasFallbackPlist, fallbackStatus == nil {
            do {
                try removeFallbackLaunchAgent(environment: environment)
            } catch {
                return .enabled
            }
        }
        if fallbackStatus == .enabled {
            return .enabled
        }
        if nativeStatus == .requiresApproval || fallbackStatus == .requiresApproval {
            return .requiresApproval
        }
        if fallbackStatus != nil {
            return .disabled
        }
        return LaunchAtLoginStatus(nativeStatus)
    }

    static func setEnabled(
        _ enabled: Bool,
        environment: LaunchAtLoginEnvironment
    ) async throws {
        if enabled {
            try enableLaunchAtLogin(environment: environment)
        } else {
            try await disableLaunchAtLogin(environment: environment)
        }
    }
}

private extension LaunchAtLoginClient {
    static func enableLaunchAtLogin(environment: LaunchAtLoginEnvironment) throws {
        if environment.serviceManagementStatus() == .enabled {
            try removeFallbackLaunchAgent(environment: environment)
            return
        }

        do {
            try environment.registerMainApp()
        } catch {
            guard environment.serviceManagementStatus() == .enabled else {
                try installFallbackLaunchAgent(environment: environment)
                return
            }
        }

        if environment.serviceManagementStatus() == .enabled {
            try removeFallbackLaunchAgent(environment: environment)
            return
        }

        try installFallbackLaunchAgent(environment: environment)
    }

    static func disableLaunchAtLogin(environment: LaunchAtLoginEnvironment) async throws {
        let unregisterError: Error?
        do {
            try await environment.unregisterMainApp()
            unregisterError = nil
        } catch {
            unregisterError = error
        }

        try removeFallbackLaunchAgent(environment: environment)

        if let unregisterError {
            switch environment.serviceManagementStatus() {
            case .notRegistered, .notFound:
                return
            case .enabled, .requiresApproval:
                throw unregisterError
            @unknown default:
                throw unregisterError
            }
        }
    }

    static func fallbackLaunchAgentStatus(
        environment: LaunchAtLoginEnvironment
    ) -> LaunchAtLoginStatus? {
        guard
            let executableURL = environment.executableURL(),
            let plist = fallbackPropertyList(
                plistURL: environment.plistURL,
                fileManager: environment.fileManager
            ),
            plist["Label"] as? String == launchAgentIdentifier,
            plist["RunAtLoad"] as? Bool == true,
            let arguments = plist["ProgramArguments"] as? [String],
            arguments.count == 1,
            let executablePath = arguments.first
        else {
            return nil
        }

        guard normalizedPath(executablePath) == normalizedPath(executableURL.path) else {
            return nil
        }
        return LaunchAtLoginStatus(environment.legacyPlistStatus(environment.plistURL))
    }

    static func fallbackPropertyList(
        plistURL: URL,
        fileManager: FileManager
    ) -> [String: Any]? {
        guard
            fileManager.fileExists(atPath: plistURL.path),
            let data = try? Data(contentsOf: plistURL),
            let plist = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
            ) as? [String: Any]
        else {
            return nil
        }

        return plist
    }

    static func installFallbackLaunchAgent(
        environment: LaunchAtLoginEnvironment
    ) throws {
        guard let executableURL = environment.executableURL() else {
            throw NSError(
                domain: "V2Bar.LaunchAtLogin",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Cannot resolve V2Bar executable path"]
            )
        }

        let originalPlistData: Data? = if environment.fileManager.fileExists(
            atPath: environment.plistURL.path
        ) {
            try Data(contentsOf: environment.plistURL)
        } else {
            nil
        }

        try environment.fileManager.createDirectory(
            at: environment.plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let stagingDirectoryURL = environment.plistURL.deletingLastPathComponent()
            .appendingPathComponent(launchAgentStagingDirectoryName, isDirectory: true)
        let stagingPlistURL = stagingDirectoryURL.appendingPathComponent(launchAgentPlistName)
        try environment.fileManager.createDirectory(
            at: stagingDirectoryURL,
            withIntermediateDirectories: true
        )

        let plist: [String: Any] = [
            "Label": launchAgentIdentifier,
            "ProgramArguments": [executableURL.path],
            "RunAtLoad": true,
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: stagingPlistURL, options: .atomic)

        let domain = "gui/\(environment.userID())"
        let serviceTarget = "\(domain)/\(launchAgentIdentifier)"
        try? environment.runLaunchctl(["bootout", serviceTarget])
        do {
            try environment.runLaunchctl(["bootstrap", domain, stagingPlistURL.path])
            try commitFallbackLaunchAgent(
                stagingPlistURL: stagingPlistURL,
                environment: environment
            )
        } catch let installationError {
            do {
                try rollbackFailedFallbackInstallation(
                    stagingDirectoryURL: stagingDirectoryURL,
                    domain: domain,
                    serviceTarget: serviceTarget,
                    originalPlistData: originalPlistData,
                    environment: environment
                )
            } catch {
                throw error
            }
            throw installationError
        }

        removeStagingDirectory(stagingDirectoryURL, fileManager: environment.fileManager)
    }

    static func commitFallbackLaunchAgent(
        stagingPlistURL: URL,
        environment: LaunchAtLoginEnvironment
    ) throws {
        if environment.fileManager.fileExists(atPath: environment.plistURL.path) {
            try environment.replaceItemAt(environment.plistURL, stagingPlistURL)
        } else {
            try environment.moveItemAt(stagingPlistURL, environment.plistURL)
        }
    }

    static func rollbackFailedFallbackInstallation(
        stagingDirectoryURL: URL,
        domain: String,
        serviceTarget: String,
        originalPlistData: Data?,
        environment: LaunchAtLoginEnvironment
    ) throws {
        try? environment.runLaunchctl(["bootout", serviceTarget])
        removeStagingDirectory(stagingDirectoryURL, fileManager: environment.fileManager)

        if let originalPlistData {
            try originalPlistData.write(to: environment.plistURL, options: .atomic)
            try environment.runLaunchctl(["bootstrap", domain, environment.plistURL.path])
        } else if environment.fileManager.fileExists(atPath: environment.plistURL.path) {
            try environment.fileManager.removeItem(at: environment.plistURL)
        }
    }

    static func removeFallbackLaunchAgent(environment: LaunchAtLoginEnvironment) throws {
        let hasFallbackPlist = environment.fileManager.fileExists(atPath: environment.plistURL.path)
        let legacyStatus = hasFallbackPlist
            ? environment.legacyPlistStatus(environment.plistURL)
            : nil
        let fallbackStatus = fallbackLaunchAgentStatus(environment: environment)
        let serviceTarget = "gui/\(environment.userID())/\(launchAgentIdentifier)"
        var cleanupError: Error?

        do {
            try environment.runLaunchctl(["bootout", serviceTarget])
        } catch {
            if legacyStatus == .enabled || fallbackStatus == .enabled {
                cleanupError = error
            }
        }

        if environment.fileManager.fileExists(atPath: environment.plistURL.path) {
            do {
                try environment.removeItemAt(environment.plistURL)
            } catch {
                cleanupError = cleanupError ?? error
            }
        }

        let stagingDirectoryURL = environment.plistURL.deletingLastPathComponent()
            .appendingPathComponent(launchAgentStagingDirectoryName, isDirectory: true)
        removeStagingDirectory(stagingDirectoryURL, fileManager: environment.fileManager)

        if let cleanupError {
            throw cleanupError
        }
    }

    static func removeStagingDirectory(_ url: URL, fileManager: FileManager) {
        guard fileManager.fileExists(atPath: url.path) else { return }
        try? fileManager.removeItem(at: url)
    }

    static func runLaunchctl(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "V2Bar.LaunchAtLogin",
                code: Int(process.terminationStatus),
                userInfo: [
                    NSLocalizedDescriptionKey: "launchctl \(arguments.joined(separator: " ")) failed",
                ]
            )
        }
    }

    static func normalizedPath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
