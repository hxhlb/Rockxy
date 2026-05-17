import Foundation

// MARK: - CertificateMenuAction

enum CertificateMenuAction: Equatable {
    case installOnMac
    case installOniOSDevice
    case installOniOSSimulator
    case installOnAndroidDevice
    case installOnAndroidEmulator
    case installOnJavaVMs
    case installOnDevelopment(SetupTarget.ID)
    case installOnFirefox
    case addCustomCertificates
    case export(CertificateExportFormat)
    case resetAll
}

// MARK: - CertificateMenuRoute

enum CertificateMenuRoute: Equatable {
    case openCertificateSetupGuide
    case openDeveloperSetup(targetID: SetupTarget.ID, tab: SetupDetailTab)
    case openCustomCertificates
    case export(CertificateExportFormat)
    case resetAll
}

// MARK: - CertificateMenuActionRouter

struct CertificateMenuActionRouter {
    func route(for action: CertificateMenuAction) -> CertificateMenuRoute {
        switch action {
        case .installOnMac:
            return .openCertificateSetupGuide
        case .installOniOSDevice:
            return .openDeveloperSetup(targetID: .iosDevice, tab: .setup)
        case .installOniOSSimulator:
            return .openDeveloperSetup(targetID: .iosSimulator, tab: .setup)
        case .installOnAndroidDevice:
            return .openDeveloperSetup(targetID: .androidDevice, tab: .setup)
        case .installOnAndroidEmulator:
            return .openDeveloperSetup(targetID: .androidEmulator, tab: .setup)
        case .installOnJavaVMs:
            return .openDeveloperSetup(targetID: .javaVMs, tab: .setup)
        case .installOnDevelopment(let targetID):
            return .openDeveloperSetup(targetID: targetID, tab: .setup)
        case .installOnFirefox:
            return .openDeveloperSetup(targetID: .firefox, tab: .setup)
        case .addCustomCertificates:
            return .openCustomCertificates
        case .export(let format):
            return .export(format)
        case .resetAll:
            return .resetAll
        }
    }
}
