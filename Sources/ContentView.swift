import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    @State private var sourceURL: URL?
    @State private var destinationURL: URL?
    @State private var profileURL: URL?
    @State private var p12URL: URL?

    @State private var bundleIdentifier = ""

    @State private var deleteFailedCopies = false

    @State private var showSourcePicker = false
    @State private var showDestinationPicker = false
    @State private var showProfilePicker = false
    @State private var showP12Picker = false

    @State private var statusMessage = "작업 준비 완료"
    @State private var isProcessing = false

    var body: some View {

        NavigationView {

            ScrollView {

                VStack(spacing: 22) {

                    headerSection

                    statusSection

                    folderSection

                    certificateSection

                    signingSection

                    startButton

                    footerSection
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle)

        .fileImporter(
            isPresented: $showSourcePicker,
            allowedContentTypes: [
                .folder,
                UTType(filenameExtension: "framework") ?? .folder
            ],
            allowsMultipleSelection: false
        ) { result in
            handleSelection(result) { sourceURL = $0 }
        }

        .fileImporter(
            isPresented: $showDestinationPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleSelection(result) { destinationURL = $0 }
        }

        .fileImporter(
            isPresented: $showProfilePicker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            handleSelection(result) { profileURL = $0 }
        }

        .fileImporter(
            isPresented: $showP12Picker,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            handleSelection(result) { p12URL = $0 }
        }
    }

    // MARK: - Header

    private var headerSection: some View {

        VStack(alignment: .leading, spacing: 8) {

            HStack {

                Image(systemName: "signature")
                    .font(.system(size: 30, weight: .bold))

                Spacer()

                Text("NX2APPLE SIGNER")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
            }

            Text("Framework Manager")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Framework를 안전하게 복사하고 일괄 서명합니다.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(22)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
    }

    // MARK: - Status

    private var statusSection: some View {

        HStack(spacing: 14) {

            Image(systemName: isProcessing
                  ? "arrow.triangle.2.circlepath"
                  : "checkmark.circle.fill")
                .font(.system(size: 26))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4) {

                Text("작업 상태")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(statusMessage)
                    .font(.headline)
            }

            Spacer()
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    // MARK: - Folder Selection

    private var folderSection: some View {

        VStack(alignment: .leading, spacing: 16) {

            sectionTitle("폴더 설정", icon: "folder")

            fileSelectionRow(
                title: "원본 Framework 폴더",
                subtitle: sourceURL?.lastPathComponent ?? "원본 폴더 선택",
                icon: "folder.badge.plus",
                action: { showSourcePicker = true }
            )

            fileSelectionRow(
                title: "대상 Frameworks 폴더",
                subtitle: destinationURL?.lastPathComponent ?? "복사할 위치 선택",
                icon: "folder.fill.badge.plus",
                action: { showDestinationPicker = true }
            )

            Text("원본은 그대로 유지하며, 앱 내부 작업 공간에 복사한 뒤 서명합니다.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(18)
    }

    // MARK: - Certificate

    private var certificateSection: some View {

        VStack(alignment: .leading, spacing: 16) {

            sectionTitle("인증서 설정", icon: "lock.shield")

            fileSelectionRow(
                title: "MobileProvision",
                subtitle: profileURL?.lastPathComponent ?? "프로비저닝 프로파일 선택",
                icon: "doc.badge.gearshape",
                action: { showProfilePicker = true }
            )

            fileSelectionRow(
                title: "P12 인증서",
                subtitle: p12URL?.lastPathComponent ?? "P12 파일 선택",
                icon: "key.horizontal",
                action: { showP12Picker = true }
            )

            VStack(alignment: .leading, spacing: 8) {

                Text("호스트 앱 Bundle ID")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                TextField(
                    "예: com.example.nx2apple",
                    text: $bundleIdentifier
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(14)
                .background(Color(.tertiarySystemGroupedBackground))
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(18)
    }

    // MARK: - Signing Options

    private var signingSection: some View {

        VStack(alignment: .leading, spacing: 16) {

            sectionTitle("서명 옵션", icon: "gearshape.2")

            Toggle(
                "서명 실패 복사본 자동 삭제",
                isOn: $deleteFailedCopies
            )

            Text(deleteFailedCopies
                 ? "서명에 실패한 작업용 복사본을 삭제합니다. 원본은 삭제하지 않습니다."
                 : "실패한 작업용 복사본을 보존하여 오류를 확인할 수 있습니다.")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            Label("원본 파일 보호: 항상 활성화", systemImage: "lock.fill")
                .font(.subheadline)
                .foregroundColor(.green)
        }
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(18)
    }

    // MARK: - Start Button

    private var startButton: some View {

        Button {

            statusMessage = "서명 엔진 연결을 기다리고 있습니다."

        } label: {

            HStack {

                Image(systemName: "signature")

                Text("일괄 서명 시작")
                    .fontWeight(.bold)
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(18)
            .background(Color.blue)
            .cornerRadius(16)
        }
        .disabled(isProcessing)
    }

    // MARK: - Footer

    private var footerSection: some View {

        VStack(spacing: 6) {

            Text("NX2Apple Signer")
                .font(.caption)
                .fontWeight(.bold)

            Text("Original Protection · Batch Signing")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Components

    private func sectionTitle(
        _ title: String,
        icon: String
    ) -> some View {

        HStack {

            Image(systemName: icon)
                .foregroundColor(.blue)

            Text(title)
                .font(.headline)
        }
    }

    private func fileSelectionRow(
        title: String,
        subtitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            HStack(spacing: 14) {

                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {

                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(Color(.tertiarySystemGroupedBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - File Selection Handler

    private func handleSelection(
        _ result: Result<[URL], Error>,
        completion: (URL) -> Void
    ) {

        switch result {

        case .success(let urls):

            guard let url = urls.first else {
                return
            }

            completion(url)

        case .failure(let error):

            statusMessage = "파일 선택 오류: \(error.localizedDescription)"
        }
    }
}
