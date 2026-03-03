import Foundation

struct WebDAVFile {
    let path: String
    let name: String
    let isDirectory: Bool
    let size: Int64?
    let lastModified: Date?
    let etag: String?
}
