import Foundation

struct RecentFileEntry: Codable, Equatable, Identifiable {
    let path: String

    var id: String { path }

    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var fileURL: URL {
        URL(fileURLWithPath: path)
    }
}
