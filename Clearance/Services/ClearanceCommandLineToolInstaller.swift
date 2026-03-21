import Foundation

enum ClearanceCommandLineToolInstallerError: LocalizedError, Equatable {
    case existingInstallIsNotASymlink(URL)
    case installDirectoryNotWritable(URL)

    var errorDescription: String? {
        switch self {
        case .existingInstallIsNotASymlink(let url):
            return "\(url.path) already exists and is not a symlink."
        case .installDirectoryNotWritable(let url):
            return "\(url.path) is not writable for your user. Install `clearance` there with admin privileges, or create the symlink in another directory on your PATH."
        }
    }
}

struct ClearanceCommandLineToolInstaller {
    static let installURL = URL(fileURLWithPath: "/usr/local/bin/clearance")

    static func install(
        helperExecutableURL: URL,
        at installURL: URL = installURL,
        fileManager: FileManager = .default
    ) throws {
        let installDirectoryURL = installURL.deletingLastPathComponent()

        if fileManager.fileExists(atPath: installDirectoryURL.path),
           !fileManager.isWritableFile(atPath: installDirectoryURL.path) {
            throw ClearanceCommandLineToolInstallerError.installDirectoryNotWritable(installDirectoryURL)
        }

        do {
            try fileManager.createDirectory(
                at: installDirectoryURL,
                withIntermediateDirectories: true
            )
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteNoPermissionError {
            throw ClearanceCommandLineToolInstallerError.installDirectoryNotWritable(installDirectoryURL)
        }

        if (try? fileManager.destinationOfSymbolicLink(atPath: installURL.path)) != nil {
            try fileManager.removeItem(at: installURL)
        } else if fileManager.fileExists(atPath: installURL.path) {
            throw ClearanceCommandLineToolInstallerError.existingInstallIsNotASymlink(installURL)
        }

        do {
            try fileManager.createSymbolicLink(
                at: installURL,
                withDestinationURL: helperExecutableURL
            )
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteNoPermissionError {
            throw ClearanceCommandLineToolInstallerError.installDirectoryNotWritable(installDirectoryURL)
        }
    }
}
