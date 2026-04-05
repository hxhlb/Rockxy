import Foundation
import os

// Boots the privileged helper, restores stale proxy state, and starts the XPC listener.

private let identity = RockxyIdentity.current
private let logger = Logger(subsystem: identity.logSubsystem, category: "Main")

logger.info("RockxyHelperTool starting up")

// Check for stale proxy settings from a previous crash
CrashRecovery.restoreIfNeeded()

let delegate = HelperDelegate()
let machServiceName = identity.helperMachServiceName
let listener = NSXPCListener(machServiceName: machServiceName)
listener.delegate = delegate
listener.resume()

logger.info("RockxyHelperTool listening on Mach service \(machServiceName)")

RunLoop.current.run()
