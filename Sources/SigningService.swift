
import Foundation
import RorkSign

enum SigningService {

    enum SigningError: LocalizedError {
        case invalidFramework
        case missingBundleIdentifier
        case teamIDMismatch(expected: String, actual: String)

        var errorDescription: String? {
            switch self {
            case .invalidFramework:
                return "선택한 폴더가 올바른 Framework가 아닙니다."

            case .missingBundleIdentifier:
                return "호스트 앱의 Bundle ID를 확인할 수 없습니다."

            case .teamIDMismatch(let expected, let actual):
                return """
                인증서 Team ID가 일치하지 않습니다.
                예상: \(expected)
                확인: \(actual)
                """
            }
        }
    }

    static func signFramework(
        frameworkURL: URL,
        profileURL: URL,
        p12URL: URL,
        password: String,
        hostBundleIdentifier: String
    ) throws {

        guard frameworkURL.pathExtension == "framework" else {
            throw SigningError.invalidFramework
        }

        guard !hostBundleIdentifier.isEmpty else {
            throw SigningError.missingBundleIdentifier
        }

        let frameworkAccess =
            frameworkURL.startAccessingSecurityScopedResource()

        let profileAccess =
            profileURL.startAccessingSecurityScopedResource()

        let p12Access =
            p12URL.startAccessingSecurityScopedResource()

        defer {
            if frameworkAccess {
                frameworkURL.stopAccessingSecurityScopedResource()
            }

            if profileAccess {
                profileURL.stopAccessingSecurityScopedResource()
            }

            if p12Access {
                p12URL.stopAccessingSecurityScopedResource()
            }
        }

        let profileData = try Data(contentsOf: profileURL)
        let credentialData = try Data(contentsOf: p12URL)

        let teamID = try RorkSigner.validatedTeamIdentifier(
            provisioningProfileData: profileData,
            credentialData: credentialData,
            password: password
        )

        print("[FrameworkSigner] 인증서 검증 완료")
        print("[FrameworkSigner] Team ID: \(teamID)")

        var options = FrameworkSigningOptions()
        options.codeDirectoryIdentifier = hostBundleIdentifier

        try RorkSigner.signFrameworkWithCredential(
            at: frameworkURL,
            provisioningProfileData: profileData,
            credentialData: credentialData,
            password: password,
            options: options
        )

        print("[FrameworkSigner] 서명 완료")
        print("[FrameworkSigner] Framework: \(frameworkURL.lastPathComponent)")
    }
}
