import Foundation

/// 圖片檔的存放規則：和文件放在同一個資料夾下的 `md.img` 裡，Markdown 記相對路徑 `md.img/檔名`。
enum ImageStore {
    static let folderName = "md.img"

    /// 路徑是不是相對於文件的本機檔案（不是網址，也不是絕對路徑）。
    static func isRelative(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && URL(string: path)?.scheme == nil
    }

    /// 相對路徑在文件所在資料夾裡對應的檔案。
    static func fileURL(for path: String, in directory: URL) -> URL {
        directory.appendingPathComponent(path.removingPercentEncoding ?? path)
    }

    /// 檔名裡的空白與括號會讓 Markdown 的圖片語法變得難讀，換成連字號。
    static func sanitized(_ fileName: String) -> String {
        let cleaned = fileName
            .components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: "-")
            .replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        return cleaned.isEmpty ? "image" : cleaned
    }

    /// 幫來源圖片挑一個存放路徑。資料夾裡已有內容相同的同名檔案就直接沿用；
    /// 名稱被別的圖片用掉時在後面加編號，不覆寫既有檔案。
    static func path(for source: URL, in directory: URL?, taken: Set<String>) -> String {
        let name = sanitized(source.lastPathComponent) as NSString
        let base = name.deletingPathExtension
        let ext = name.pathExtension
        var index = 1
        while true {
            let fileName = index == 1 ? name as String : "\(base)-\(index)" + (ext.isEmpty ? "" : ".\(ext)")
            let path = "\(folderName)/\(fileName)"
            index += 1
            if taken.contains(path) { continue }
            if let directory {
                let existing = fileURL(for: path, in: directory)
                if FileManager.default.fileExists(atPath: existing.path),
                   !FileManager.default.contentsEqual(atPath: existing.path, andPath: source.path) { continue }
            }
            return path
        }
    }

    /// 把圖片複製到文件旁邊。目的地已經有檔案就不動它。
    static func copy(_ source: URL, to path: String, in directory: URL) throws {
        let destination = fileURL(for: path, in: directory)
        guard !FileManager.default.fileExists(atPath: destination.path) else { return }
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: source, to: destination)
    }
}
