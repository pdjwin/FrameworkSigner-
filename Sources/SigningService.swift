import Foundation
import RorkSign
import CryptoKit

struct FrameworkSigningResult {

    var success: [String] = []
    var failed: [String] = []
    var skipped: [String] = []
    var replaced: [String] = []
    var retainedFailedCopies: [String] = []
}

enum SigningService {

    enum SigningError: LocalizedError {

        case invalidSource
        case invalidDestination
        case missingBundleIdentifier
        case noFrameworkFound
        case copyFailed(String)
        case destinationConflict(String)

        var errorDescription: String? {

            switch self {

            case .invalidSource:
                return "원본 폴더에 접근할 수 없습니다."

            case .invalidDestination:
                return "저장 폴더에 접근할 수 없습니다."

            case .missingBundleIdentifier:
                return "Bundle ID가 필요합니다."

            case .noFrameworkFound:
                return "Framework를 찾지 못했습니다."

            case .copyFailed(let message):
                return "복사 실패: \(message)"

            case .destinationConflict(let name):
                return "기존 파일과 내용이 달라 자동 교체하지 않았습니다: \(name)"
            }
        }
    }

    // MARK: Main

    static func signFolder(
        sourceURL: URL,
        destinationURL: URL,
        profileURL: URL,
        p12URL: URL,
        password: String,
        hostBundleIdentifier: String,
        deleteFailedCopies: Bool,
        progress: @escaping (String) -> Void
    ) throws -> FrameworkSigningResult {

        guard !hostBundleIdentifier.isEmpty else {
            throw SigningError.missingBundleIdentifier
        }

        let accessURLs = [
            sourceURL,
            destinationURL,
            profileURL,
            p12URL
        ]

        var accessed: [URL] = []

        for url in accessURLs {

            if url.startAccessingSecurityScopedResource() {
                accessed.append(url)
            }
        }

        defer {

            for url in accessed {
                url.stopAccessingSecurityScopedResource()
            }
        }

        let fileManager = FileManager.default

        guard fileManager.fileExists(
            atPath: sourceURL.path
        ) else {
            throw SigningError.invalidSource
        }

        guard fileManager.fileExists(
            atPath: destinationURL.path
        ) else {
            throw SigningError.invalidDestination
        }

        // MARK: Certificate Validation

        progress("인증서 검증 시작")

        let profileData = try Data(contentsOf: profileURL)
        let credentialData = try Data(contentsOf: p12URL)

        let teamID = try RorkSigner.validatedTeamIdentifier(
            provisioningProfileData: profileData,
            credentialData: credentialData,
            password: password
        )

        progress("인증서 검증 성공")
        progress("Team ID: \(teamID)")

        // MARK: Workspace

        let documents = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let workspace = documents
            .appendingPathComponent(
                "Workspace",
                isDirectory: true
            )

        try fileManager.createDirectory(
            at: workspace,
            withIntermediateDirectories: true
        )

        let jobID = UUID().uuidString

        let jobDirectory = workspace
            .appendingPathComponent(
                jobID,
                isDirectory: true
            )

        try fileManager.createDirectory(
            at: jobDirectory,
            withIntermediateDirectories: true
        )

        progress("임시 작업 폴더 생성: \(jobID)")

        let copiedSource = jobDirectory
            .appendingPathComponent(
                sourceURL.lastPathComponent,
                isDirectory: true
            )

        // MARK: File Enumeration

        let sourceFiles = try collectFiles(
            at: sourceURL
        )

        guard !sourceFiles.isEmpty else {
            throw SigningError.invalidSource
        }

        let totalBytes = sourceFiles.reduce(Int64(0)) {
            $0 + $1.size
        }

        progress("복사 대상 파일: \(sourceFiles.count)개")
        progress("전체 복사 용량: \(totalBytes) bytes")

        // MARK: Copy

        try fileManager.createDirectory(
            at: copiedSource.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var copiedBytes: Int64 = 0

        for (index, item) in sourceFiles.enumerated() {

            let relativePath = String(
                item.url.path.dropFirst(sourceURL.path.count)
            )
            .trimmingCharacters(
                in: CharacterSet(charactersIn: "/")
            )

            let targetURL = copiedSource
                .appendingPathComponent(relativePath)

            progress("FILE:\(relativePath)")

            try copyItemSafely(
                from: item.url,
                to: targetURL
            )

            copiedBytes += item.size

            progress(
                "PROGRESS:\(index + 1)/\(sourceFiles.count)"
            )

            progress(
                "복사 완료: \(relativePath)"
            )

            if item.isDirectory {
                continue
            }
        }

        progress("원본 폴더 복사 완료")
        progress("원본 파일은 수정하지 않았습니다.")

        // MARK: Framework Search

        let frameworks = try findFrameworks(
            in: copiedSource
        )

        guard !frameworks.isEmpty else {
            throw SigningError.noFrameworkFound
        }

        progress("검색된 Framework: \(frameworks.count)개")

        var result = FrameworkSigningResult()

        // MARK: Sign

        for (index, frameworkURL) in frameworks.enumerated() {

            let name = frameworkURL.lastPathComponent

            progress(
                "[\(index + 1)/\(frameworks.count)] \(name) 서명 시작"
            )

            do {

                var options = FrameworkSigningOptions()

                options.codeDirectoryIdentifier =
                    hostBundleIdentifier

                try RorkSigner.signFrameworkWithCredential(
                    at: frameworkURL,
                    provisioningProfileData: profileData,
                    credentialData: credentialData,
                    password: password,
                    options: options
                )

                progress("\(name) 서명 성공")

            } catch {

                let message = error.localizedDescription

                result.failed.append(
                    "\(name): \(message)"
                )

                progress(
                    "\(name) 서명 실패: \(message)"
                )

                if deleteFailedCopies {

                    try? fileManager.removeItem(
                        at: frameworkURL
                    )

                    progress(
                        "\(name) 임시 복사본 삭제"
                    )

                } else {

                    result.retainedFailedCopies.append(name)

                    progress(
                        "\(name) 임시 복사본 보존"
                    )
                }

                continue
            }

            // MARK: Destination

            let relativePath = String(
                frameworkURL.path.dropFirst(
                    copiedSource.path.count
                )
            )
            .trimmingCharacters(
                in: CharacterSet(charactersIn: "/")
            )

            let outputURL = destinationURL
                .appendingPathComponent(
                    relativePath,
                    isDirectory: true
                )

            do {

                if fileManager.fileExists(
                    atPath: outputURL.path
                ) {

                    let existingHash = try directoryHash(
                        at: outputURL
                    )

                    let newHash = try directoryHash(
                        at: frameworkURL
                    )

                    if existingHash == newHash {

                        result.skipped.append(name)

                        progress(
                            "\(name) 내용이 동일하여 저장 스킵"
                        )

                        continue
                    }

                    throw SigningError.destinationConflict(name)
                }

                try fileManager.createDirectory(
                    at: outputURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )

                try fileManager.copyItem(
                    at: frameworkURL,
                    to: outputURL
                )

                result.success.append(name)

                progress(
                    "\(name) 최종 저장 성공"
                )

            } catch {

                result.failed.append(
                    "\(name): \(error.localizedDescription)"
                )

                progress(
                    "\(name) 저장 실패: \(error.localizedDescription)"
                )
            }
        }

        progress("전체 작업 완료")
        progress("성공: \(result.success.count)")
        progress("실패: \(result.failed.count)")
        progress("스킵: \(result.skipped.count)")

        return result
    }

    // MARK: File Item

    private struct FileItem {

        let url: URL
        let size: Int64
        let isDirectory: Bool
    }

    // MARK: Collect Files

    private static func collectFiles(
        at root: URL
    ) throws -> [FileItem] {

        let manager = FileManager.default

        var items: [FileItem] = []

        func visit(_ url: URL) throws {

            let attributes = try manager.attributesOfItem(
                atPath: url.path
            )

            let type = attributes[.type] as? FileAttributeType

            if type == .typeSymbolicLink {
                return
            }

            if type == .typeDirectory {

                items.append(
                    FileItem(
                        url: url,
                        size: 0,
                        isDirectory: true
                    )
                )

                let children = try manager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: nil,
                    options: []
                )

                for child in children {
                    try visit(child)
                }

            } else {

                let size = (
                    attributes[.size] as? NSNumber
                )?.int64Value ?? 0

                items.append(
                    FileItem(
                        url: url,
                        size: size,
                        isDirectory: false
                    )
                )
            }
        }

        try visit(root)

        return items
    }

    // MARK: Safe Copy

    private static func copyItemSafely(
        from source: URL,
        to destination: URL
    ) throws {

        let manager = FileManager.default

        let attributes = try manager.attributesOfItem(
            atPath: source.path
        )

        let type = attributes[.type] as? FileAttributeType

        if type == .typeSymbolicLink {

            let link = try manager.destinationOfSymbolicLink(
                atPath: source.path
            )

            try manager.createSymbolicLink(
                atPath: destination.path,
                withDestinationPath: link
            )

            return
        }

        if type == .typeDirectory {

            try manager.createDirectory(
                at: destination,
                withIntermediateDirectories: true
            )

            let children = try manager.contentsOfDirectory(
                at: source,
                includingPropertiesForKeys: nil,
                options: []
            )

            for child in children {

                try copyItemSafely(
                    from: child,
                    to: destination.appendingPathComponent(
                        child.lastPathComponent
                    )
                )
            }

        } else {

            try manager.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            try manager.copyItem(
                at: source,
                to: destination
            )
        }
    }

    // MARK: Find Frameworks

    private static func findFrameworks(
        in root: URL
    ) throws -> [URL] {

        let manager = FileManager.default

        var frameworks: [URL] = []

        if root.pathExtension.lowercased() == "framework" {

            return [root]
        }

        guard let enumerator = manager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: []
        ) else {

            throw SigningError.noFrameworkFound
        }

        for case let url as URL in enumerator {

            if url.pathExtension.lowercased() == "framework" {

                frameworks.append(url)

                enumerator.skipDescendants()
            }
        }

        return frameworks
    }

    // MARK: Directory Hash

    private static func directoryHash(
        at root: URL
    ) throws -> String {

        let manager = FileManager.default

        let files = try collectFiles(at: root)

        var hasher = SHA256()

        for item in files.sorted(
            by: { $0.url.path < $1.url.path }
        ) {

            let relativePath = String(
                item.url.path.dropFirst(root.path.count)
            )

            hasher.update(
                data: Data(relativePath.utf8)
            )

            if item.isDirectory {
                continue
            }

            let data = try Data(
                contentsOf: item.url,
                options: .mappedIfSafe
            )

            hasher.update(data: data)
        }

        return hasher.finalize()
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
