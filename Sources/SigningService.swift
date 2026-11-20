import Foundation
import CryptoKit
import RorkSign

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
        case invalidCertificate
        case destinationConflict(String)
        case copyFailed(String)

        var errorDescription: String? {

            switch self {

            case .invalidSource:
                return "원본 폴더에 접근할 수 없습니다."

            case .invalidDestination:
                return "저장 폴더에 접근할 수 없습니다."

            case .missingBundleIdentifier:
                return "Bundle ID를 입력해 주세요."

            case .noFrameworkFound:
                return "Framework를 찾지 못했습니다."

            case .invalidCertificate:
                return "인증서 검증에 실패했습니다."

            case .destinationConflict(let name):
                return "기존 파일과 내용이 다릅니다: \(name)"

            case .copyFailed(let reason):
                return "복사 실패: \(reason)"
            }
        }
    }

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

        let fileManager = FileManager.default

        let bundleID = hostBundleIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !bundleID.isEmpty else {
            throw SigningError.missingBundleIdentifier
        }

        let sourceAccess =
            sourceURL.startAccessingSecurityScopedResource()

        let destinationAccess =
            destinationURL.startAccessingSecurityScopedResource()

        let profileAccess =
            profileURL.startAccessingSecurityScopedResource()

        let p12Access =
            p12URL.startAccessingSecurityScopedResource()

        defer {

            if sourceAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }

            if destinationAccess {
                destinationURL.stopAccessingSecurityScopedResource()
            }

            if profileAccess {
                profileURL.stopAccessingSecurityScopedResource()
            }

            if p12Access {
                p12URL.stopAccessingSecurityScopedResource()
            }
        }

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

        // MARK: Certificate

        progress("인증서 데이터 읽기")

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

        let documentsURL = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]

        let workspaceURL = documentsURL
            .appendingPathComponent(
                "Workspace",
                isDirectory: true
            )

        try fileManager.createDirectory(
            at: workspaceURL,
            withIntermediateDirectories: true
        )

        let jobID = UUID().uuidString

        let jobURL = workspaceURL
            .appendingPathComponent(
                jobID,
                isDirectory: true
            )

        try fileManager.createDirectory(
            at: jobURL,
            withIntermediateDirectories: true
        )

        let copiedSourceURL = jobURL
            .appendingPathComponent(
                sourceURL.lastPathComponent,
                isDirectory: true
            )

        // MARK: Copy Source

        progress("원본 폴더 복사 시작")

        do {

            try copyDirectory(
                from: sourceURL,
                to: copiedSourceURL,
                progress: progress
            )

        } catch {

            try? fileManager.removeItem(at: jobURL)

            throw SigningError.copyFailed(
                error.localizedDescription
            )
        }

        progress("원본 복사 완료")
        progress("원본 파일은 변경하지 않았습니다.")

        // MARK: Find Frameworks

        var frameworks: [URL] = []

        if copiedSourceURL.pathExtension.lowercased() == "framework" {

            frameworks.append(copiedSourceURL)

        } else {

            guard let enumerator = fileManager.enumerator(
                at: copiedSourceURL,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey
                ],
                options: []
            ) else {

                throw SigningError.noFrameworkFound
            }

            for case let itemURL as URL in enumerator {

                if itemURL.pathExtension.lowercased() == "framework" {

                    frameworks.append(itemURL)

                    enumerator.skipDescendants()
                }
            }
        }

        guard !frameworks.isEmpty else {
            throw SigningError.noFrameworkFound
        }

        progress("검색된 Framework: \(frameworks.count)개")

        // MARK: Sign

        var result = FrameworkSigningResult()

        for (index, frameworkURL) in frameworks.enumerated() {

            let name = frameworkURL.lastPathComponent

            progress(
                "[\(index + 1)/\(frameworks.count)] \(name) 서명 시작"
            )

            do {

                var options = FrameworkSigningOptions()

                options.codeDirectoryIdentifier = bundleID

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

                progress("\(name) 서명 실패: \(message)")

                if deleteFailedCopies {

                    try? fileManager.removeItem(
                        at: frameworkURL
                    )

                    progress("\(name) 임시 복사본 삭제")

                } else {

                    result.retainedFailedCopies.append(name)

                    progress("\(name) 임시 복사본 보존")
                }

                continue
            }

            // MARK: Destination Path

            let relativePath = String(
                frameworkURL.path.dropFirst(
                    copiedSourceURL.path.count
                )
            )

            let cleanRelativePath = relativePath.hasPrefix("/")
                ? String(relativePath.dropFirst())
                : relativePath

            let outputURL: URL

            if cleanRelativePath.isEmpty {

                outputURL = destinationURL
                    .appendingPathComponent(
                        name,
                        isDirectory: true
                    )

            } else {

                outputURL = destinationURL
                    .appendingPathComponent(
                        cleanRelativePath,
                        isDirectory: true
                    )
            }

            // MARK: Duplicate Check

            if fileManager.fileExists(
                atPath: outputURL.path
            ) {

                do {

                    let existingHash = try directoryHash(
                        at: outputURL
                    )

                    let newHash = try directoryHash(
                        at: frameworkURL
                    )

                    if existingHash == newHash {

                        result.skipped.append(name)

                        progress(
                            "\(name) 동일 파일 확인 - 저장 생략"
                        )

                        continue
                    }

                    result.failed.append(
                        "\(name): 기존 파일과 내용이 다릅니다."
                    )

                    progress(
                        "\(name) 기존 파일 보호 - 자동 덮어쓰기 안 함"
                    )

                    continue

                } catch {

                    result.failed.append(
                        "\(name): 비교 실패 - \(error.localizedDescription)"
                    )

                    progress(
                        "\(name) 비교 실패 - 기존 파일 보호"
                    )

                    continue
                }
            }

            // MARK: Save

            do {

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
                    "\(name) 저장 성공"
                )

            } catch {

                result.failed.append(
                    "\(name): 저장 실패 - \(error.localizedDescription)"
                )

                progress(
                    "\(name) 저장 실패"
                )
            }
        }

        progress("전체 작업 완료")
        progress("성공: \(result.success.count)")
        progress("실패: \(result.failed.count)")
        progress("스킵: \(result.skipped.count)")
        progress("교체: \(result.replaced.count)")

        return result
    }

    // MARK: Recursive Copy

    private static func copyDirectory(
        from source: URL,
        to destination: URL,
        progress: @escaping (String) -> Void
    ) throws {

        let manager = FileManager.default

        var isDirectory: ObjCBool = false

        guard manager.fileExists(
            atPath: source.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {

            throw SigningError.invalidSource
        }

        try manager.createDirectory(
            at: destination,
            withIntermediateDirectories: true
        )

        let contents = try manager.contentsOfDirectory(
            at: source,
            includingPropertiesForKeys: [
                .isDirectoryKey,
                .isSymbolicLinkKey
            ],
            options: []
        )

        for item in contents {

            let target = destination
                .appendingPathComponent(
                    item.lastPathComponent
                )

            progress("FILE:\(item.lastPathComponent)")

            let values = try item.resourceValues(
                forKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey
                ]
            )

            if values.isSymbolicLink == true {

                let linkDestination = try manager.destinationOfSymbolicLink(
                    atPath: item.path
                )

                try manager.createSymbolicLink(
                    atPath: target.path,
                    withDestinationPath: linkDestination
                )

            } else if values.isDirectory == true {

                try copyDirectory(
                    from: item,
                    to: target,
                    progress: progress
                )

            } else {

                try manager.copyItem(
                    at: item,
                    to: target
                )
            }
        }
    }

    // MARK: Directory Hash

    private static func directoryHash(
        at directory: URL
    ) throws -> String {

        let manager = FileManager.default

        var entries: [(String, String)] = []

        func scan(
            _ folder: URL,
            relative: String
        ) throws {

            let items = try manager.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [
                    .isDirectoryKey,
                    .isSymbolicLinkKey
                ],
                options: []
            )

            for item in items {

                let relativePath = relative.isEmpty
                    ? item.lastPathComponent
                    : relative + "/" + item.lastPathComponent

                let values = try item.resourceValues(
                    forKeys: [
                        .isDirectoryKey,
                        .isSymbolicLinkKey
                    ]
                )

                if values.isSymbolicLink == true {

                    let target = try manager.destinationOfSymbolicLink(
                        atPath: item.path
                    )

                    entries.append(
                        ("L:\(relativePath)", target)
                    )

                } else if values.isDirectory == true {

                    entries.append(
                        ("D:\(relativePath)", "")
                    )

                    try scan(
                        item,
                        relative: relativePath
                    )

                } else {

                    let data = try Data(contentsOf: item)

                    let digest = SHA256.hash(data: data)

                    let hash = digest
                        .map { String(format: "%02x", $0) }
                        .joined()

                    entries.append(
                        ("F:\(relativePath)", hash)
                    )
                }
            }
        }

        try scan(
            directory,
            relative: ""
        )

        let combined = entries
            .sorted { $0.0 < $1.0 }
            .map { "\($0.0)=\($0.1)" }
            .joined(separator: "\n")

        let digest = SHA256.hash(
            data: Data(combined.utf8)
        )

        return digest
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
