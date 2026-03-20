import Foundation

enum ClearanceCommandLineToolInstallerError: LocalizedError, Equatable {
    case existingInstallIsNotASymlink(URL)

    var errorDescription: String? {
        switch self {
        case .existingInstallIsNotASymlink(let url):
            return "\(url.path) already exists and is not a symlink."
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
        try fileManager.createDirectory(
            at: installURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if (try? fileManager.destinationOfSymbolicLink(atPath: installURL.path)) != nil {
            try fileManager.removeItem(at: installURL)
        } else if fileManager.fileExists(atPath: installURL.path) {
            throw ClearanceCommandLineToolInstallerError.existingInstallIsNotASymlink(installURL)
        }

        try fileManager.createSymbolicLink(
            at: installURL,
            withDestinationURL: helperExecutableURL
        )
    }
}
