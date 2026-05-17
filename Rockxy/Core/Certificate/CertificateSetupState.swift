import Foundation

// MARK: - CertificateSetupState

enum CertificateSetupState: Equatable {
    case installedAndTrusted
    case installedNotTrusted
    case generatedOnly
    case missing

    init(snapshot: RootCAStatusSnapshot) {
        if snapshot.isInstalledInKeychain, snapshot.isSystemTrustValidated {
            self = .installedAndTrusted
        } else if snapshot.isInstalledInKeychain {
            self = .installedNotTrusted
        } else if snapshot.hasGeneratedCertificate {
            self = .generatedOnly
        } else {
            self = .missing
        }
    }

    var title: String {
        switch self {
        case .installedAndTrusted:
            String(localized: "Installed & Trusted")
        case .installedNotTrusted:
            String(localized: "Installed, Trust Required")
        case .generatedOnly:
            String(localized: "Generated, Not Installed")
        case .missing:
            String(localized: "Certificate Missing")
        }
    }

    var message: String {
        switch self {
        case .installedAndTrusted:
            String(localized: "Rockxy Certificate is ready.")
        case .installedNotTrusted:
            String(localized: "The root CA is installed, but macOS has not fully trusted it for TLS yet.")
        case .generatedOnly:
            String(localized: "The root CA exists locally. Install and trust it in Keychain to decrypt HTTPS traffic.")
        case .missing:
            String(localized: "Generate Rockxy's root CA, then install and trust it in Keychain.")
        }
    }

    var systemImageName: String {
        switch self {
        case .installedAndTrusted:
            "checkmark.circle.fill"
        case .installedNotTrusted:
            "exclamationmark.triangle.fill"
        case .generatedOnly:
            "certificate.fill"
        case .missing:
            "xmark.circle.fill"
        }
    }

    var isReady: Bool {
        self == .installedAndTrusted
    }
}
