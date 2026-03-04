import CryptoKit
import Foundation

actor SkillFileWorker {
    struct InstallDestination: Sendable {
        let rootURL: URL
        let storageKey: String
    }

    struct ScannedSkillData: Sendable {
        let id: String
        let name: String
        let displayName: String
        let description: String
        let folderURL: URL
        let skillMarkdownURL: URL
        let references: [SkillReference]
        let stats: SkillStats
    }

    func loadMarkdown(at url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
    }

    func saveMarkdown(at url: URL, content: String) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }

    func scanSkills(at baseURL: URL, storageKey: String) throws -> [ScannedSkillData] {
        let fileManager = FileManager.default

        // Directory symlinks can fail URL-based enumeration on macOS.
        let directoryURL = baseURL.resolvingSymlinksInPath()

        guard fileManager.fileExists(atPath: directoryURL.path) else {
            return []
        }

        let items = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        return items.compactMap { url -> ScannedSkillData? in
            // Resolve symlinks for each item to properly detect symlinked skill directories
            let resolvedURL = url.resolvingSymlinksInPath()
            let values = try? resolvedURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { return nil }

            let name = url.lastPathComponent
            let skillFileURL = resolvedURL.appendingPathComponent("SKILL.md")
            guard fileManager.fileExists(atPath: skillFileURL.path) else { return nil }

            let markdown = (try? String(contentsOf: skillFileURL, encoding: .utf8)) ?? ""
            let metadata = parseMetadata(from: markdown)

            let references = referenceFiles(in: resolvedURL.appendingPathComponent("references"))
            let stats = SkillStats(
                references: references.count,
                assets: countEntries(in: resolvedURL.appendingPathComponent("assets")),
                scripts: countEntries(in: resolvedURL.appendingPathComponent("scripts")),
                templates: countEntries(in: resolvedURL.appendingPathComponent("templates"))
            )

            return ScannedSkillData(
                id: "\(storageKey)-\(name)",
                name: name,
                displayName: formatTitle(metadata.name ?? name),
                description: metadata.description ?? "No description available.",
                folderURL: resolvedURL,
                skillMarkdownURL: skillFileURL,
                references: references,
                stats: stats
            )
        }
    }

    private func parseMetadata(from markdown: String) -> SkillMetadata {
        let lines = markdown.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var name: String?
        var description: String?

        if lines.first?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "---" {
            var index = 1
            while index < lines.count {
                let line = String(lines[index])
                if line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) == "---" {
                    break
                }
                if let (key, value) = parseFrontmatterLine(line) {
                    if key == "name" {
                        name = value
                    } else if key == "description" {
                        description = value
                    }
                }
                index += 1
            }
        }

        if name == nil || description == nil {
            let fallback = parseMarkdownFallback(from: lines)
            name = name ?? fallback.name
            description = description ?? fallback.description
        }

        return SkillMetadata(name: name, description: description)
    }

    private func parseFrontmatterLine(_ line: String) -> (String, String)? {
        let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let rawValue = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        let value = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
        return (key, value)
    }

    private func parseMarkdownFallback(from lines: [Substring]) -> SkillMetadata {
        var title: String?
        var description: String?

        var index = 0
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespacesAndNewlines)
            if title == nil, line.hasPrefix("# ") {
                title = String(line.dropFirst(2)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if description == nil, !line.isEmpty, !line.hasPrefix("#") {
                description = String(line)
                break
            }
            index += 1
        }

        return SkillMetadata(name: title, description: description)
    }

    private func formatTitle(_ title: String) -> String {
        let normalized = title
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        return normalized
            .split(separator: " ")
            .map { $0.capitalized }
            .joined(separator: " ")
    }

    private func countEntries(in url: URL) -> Int {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        return items.count
    }

    private func referenceFiles(in url: URL) -> [SkillReference] {
        guard let items = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        let references = items.compactMap { fileURL -> SkillReference? in
            let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { return nil }
            guard fileURL.pathExtension.lowercased() == "md" else { return nil }

            let filename = fileURL.deletingPathExtension().lastPathComponent
            return SkillReference(
                id: fileURL.path,
                name: formatTitle(filename),
                url: fileURL
            )
        }

        return references.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }
}
