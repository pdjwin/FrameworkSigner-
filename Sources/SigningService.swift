import Foundation
import RorkSign

struct FrameworkSigningResult {
    var success: [String] = []
    var failed: [String] = []
    var retainedFailedCopies: [String] = []
}

enum SigningService {

    enum SigningError: LocalizedError {

        case invalidSource
        case invalidDestination
        case missingBundleIdentifier
        case noFrameworkFound
        case destinationAlreadyExists(String)
        case copyFailed(String)

        var errorDescription: String? {

            switch self {

            case .invalidSource:
                return "원본 폴더에 접근할 수 없습니다."

            case .invalidDestination:
                return "대상 Frameworks 폴더에 접근할 수 없습니다."

            case .missingBundleIdentifier:
                return "호스트 앱 Bundle ID가 필요합니다."

            case .noFrameworkFound:
                return "선택한 폴더에서 Framework를 찾지 못했습니다."

            case .destinationAlreadyExists(let name):
                return "대상 폴더에 동일한 Framework가 있습니다: \(name)"

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

        guard !hostBundleIdentifier.isEmpty else {
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

        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw SigningError.invalidSource
        }

        guard fileManager.fileExists(atPath: destinationURL.path) else {
            throw SigningError.invalidDestination
        }

        progress("인증서 정보를 확인합니다.")

        let profileData = try Data(contentsOf: profileURL)
        let credentialData = try Data(contentsOf: p12URL)

        let teamID = try RorkSigner.validatedTeamIdentifier(
            provisioningProfileData: profileData,
            credentialData: credentialData,
            password: password
        )

        progress("인증서 검증 성공")
        progress("Team ID: \(teamID)")

        // 앱 내부 작업 공간

        let workspace = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent(
            "SigningWorkspace",
            isDirectory: true
        )

        try fileManager.createDirectory(
            at: workspace,
            withIntermediateDirectories: true
        )

        let jobID = UUID().uuidString

        let jobDirectory = workspace.appendingPathComponent(
            jobID,
            isDirectory: true
        )

        try fileManager.createDirectory(
            at: jobDirectory,
            withIntermediateDirectories: true
        )

        let copiedSource = jobDirectory.appendingPathComponent(
            sourceURL.lastPathComponent,
            isDirectory: true
        )

        // 원본을 작업 공간으로 복사

        do {

            progress("원본 Framework 폴더 복사 중...")

            try fileManager.copyItem(
                at: sourceURL,
                to: copiedSource
            )

        } catch {

            try? fileManager.removeItem(at: jobDirectory)

            throw SigningError.copyFailed(
                error.localizedDescription
            )
        }

        progress("원본 복사 완료")
        progress("원본 파일은 수정하지 않았습니다.")

        // Framework 검색

        var frameworks: [URL] = []

        if copiedSource.pathExtension.lowercased() == "framework" {

            frameworks.append(copiedSource)

        } else {

            guard let enumerator = fileManager.enumerator(
                at: copiedSource,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ) else {

                throw SigningError.noFrameworkFound
            }

            for case let itemURL as URL in enumerator {

                if itemURL.pathExtension.lowercased() == "framework" {

                    frameworks.append(itemURL)

                    // Framework 내부를 다시 검색하지 않음
                    enumerator.skipDescendants()
                }
            }
        }

        guard !frameworks.isEmpty else {
            throw SigningError.noFrameworkFound
        }

        progress("검색된 Framework: \(frameworks.count)개")

        var result = FrameworkSigningResult()

        // 일괄 서명

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

                result.failed.append("\(name): \(message)")

                progress("\(name) 서명 실패: \(message)")

                if deleteFailedCopies {

                    try? fileManager.removeItem(at: frameworkURL)

                    progress("\(name) 작업용 복사본 삭제")

                } else {

                    result.retainedFailedCopies.append(name)

                    progress("\(name) 작업용 복사본 보존")
                }

                continue
            }

            // 성공한 Framework만 대상 폴더로 복사

            let relativePath = String(
                frameworkURL.path.dropFirst(
                    copiedSource.path.count
                )
            )

            let relativeURL = relativePath.hasPrefix("/")
                ? String(relativePath.dropFirst())
                : relativePath

            let outputURL: URL

            if relativeURL.isEmpty {

                outputURL = destinationURL.appendingPathComponent(
                    name,
                    isDirectory: true
                )

            } else {

                outputURL = destinationURL.appendingPathComponent(
                    relativeURL,
                    isDirectory: true
                )
            }

            do {

                guard !fileManager.fileExists(
                    atPath: outputURL.path
                ) else {

                    throw SigningError.destinationAlreadyExists(name)
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

                progress("\(name) 대상 폴더 복사 성공")

            } catch {

                result.failed.append(
                    "\(name) 복사 실패: \(error.localizedDescription)"
                )

                progress(
                    "\(name) 복사 실패: \(error.localizedDescription)"
                )
            }
        }

        progress("전체 작업 완료")
        progress("성공: \(result.success.count)개")
        progress("실패: \(result.failed.count)개")

        return result
    }
}
