import Foundation

enum HandshakeReader {
    // MARK: Internal

    struct Handshake: Codable {
        let token: String
        let port: Int
    }

    enum HandshakeError: LocalizedError {
        case fileNotFound
        case invalidFormat(String)

        // MARK: Internal

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                "MCP handshake file not found at \(HandshakeReader.handshakePath.path)"
            case let .invalidFormat(detail):
                "MCP handshake file has invalid format: \(detail)"
            }
        }
    }

    static func readHandshake() throws -> Handshake {
        let filePath = handshakePath

        guard FileManager.default.fileExists(atPath: filePath.path) else {
            throw HandshakeError.fileNotFound
        }

        let data: Data
        do {
            data = try Data(contentsOf: filePath)
        } catch {
            throw HandshakeError.invalidFormat("could not read file: \(error.localizedDescription)")
        }

        do {
            return try JSONDecoder().decode(Handshake.self, from: data)
        } catch {
            throw HandshakeError.invalidFormat(error.localizedDescription)
        }
    }

    // MARK: Private

    private static let fallbackAppSupportDirectoryName = "com.amunx.rockxy.community"

    /// Discover the app support directory name by reading the host app's Info.plist.
    /// The CLI binary lives at Rockxy.app/Contents/MacOS/rockxy-mcp, so the app's
    /// Info.plist is at ../../Info.plist relative to the executable.
    private static var appSupportDirectoryName: String {
        if let plist = hostApplicationInfoDictionary {
            if let dirName = plist["RockxyAppSupportDirectoryName"] as? String, !dirName.isEmpty {
                return dirName
            }
            if let bundleId = plist["CFBundleIdentifier"] as? String, !bundleId.isEmpty {
                return bundleId
            }
            if let familyNamespace = plist["RockxyFamilyNamespace"] as? String, !familyNamespace.isEmpty {
                return familyNamespace
            }
        }
        return fallbackAppSupportDirectoryName
    }

    private static var handshakePath: URL {
        applicationSupportRoot
            .appendingPathComponent(appSupportDirectoryName)
            .appendingPathComponent("mcp-handshake.json")
    }

    private static var applicationSupportRoot: URL {
        FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0]
    }

    private static var hostApplicationInfoDictionary: [String: Any]? {
        guard let executablePath = Bundle.main.executablePath else {
            return nil
        }

        let executableURL = URL(fileURLWithPath: executablePath)
        let contentsURL = executableURL
            .deletingLastPathComponent() // MacOS/
            .deletingLastPathComponent() // Contents/
        let plistURL = contentsURL.appendingPathComponent("Info.plist")

        guard let plistData = try? Data(contentsOf: plistURL),
              let plist = try? PropertyListSerialization.propertyList(
                  from: plistData,
                  format: nil
              ) as? [String: Any] else
        {
            return nil
        }

        return plist
    }
}
