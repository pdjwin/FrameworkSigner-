import SwiftUI
import UniformTypeIdentifiers

enum SignerPage: String, CaseIterable, Identifiable {
    case source = "Framework"
    case destination = "저장 위치"
    case certificate = "인증서"
    case signing = "서명 실행"
    case logs = "작업 로그"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .source: return "shippingbox"
        case .destination: return "folder.badge.checkmark"
        case .certificate: return "key.horizontal"
        case .signing: return "signature"
        case .logs: return "terminal"
        }
    }
}

struct ContentView: View {

    @State private var selectedPage: SignerPage? = .source

    @State private var sourceURL: URL?
    @State private var destinationURL: URL?
    @State private var profileURL: URL?
    @State private var p12URL: URL?

    @State private var hostBundleIdentifier = ""
    @State private var password = ""

    @State private var deleteFailedCopies = true
    @State private var isSigning = false

    @State private var showingSourcePicker = false
    @State private var showingDestinationPicker = false
    @State private var showingProfilePicker = false
    @State private var showingP12Picker = false

    @State private var logs: [String] = [
        "NX2Apple Signer 준비 완료"
    ]

    @State private var successCount = 0
    @State private var failedCount = 0

var body: some View {

    Group {

        if #available(iOS 16.0, *) {

            NavigationSplitView {

                List(selection: $selectedPage) {

                    Section("WORKSPACE") {

                        ForEach(SignerPage.allCases) { page in

                            Label(
                                page.rawValue,
                                systemImage: page.icon
                            )
                            .tag(Optional(page))
                        }
                    }
                }
                .listStyle(.sidebar)
                .navigationTitle("NX2Apple")
                .navigationSplitViewColumnWidth(
                    min: 170,
                    ideal: 210,
                    max: 260
                )

            } detail: {

                detailContent
                    .navigationTitle(
                        selectedPage?.rawValue ?? "NX2Apple Signer"
                    )
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationSplitViewStyle(.balanced)

        } else {

            NavigationView {

                List(selection: $selectedPage) {

                    ForEach(SignerPage.allCases) { page in

                        NavigationLink(
                            destination: detailContent,
                            tag: page,
                            selection: $selectedPage
                        ) {
                            Label(page.rawValue, systemImage: page.icon)
                        }
                    }
                }
                .navigationTitle("NX2Apple")
            }
        }
    }
    .tint(.blue)

    .fileImporter(
        isPresented: $showingSourcePicker,
        allowedContentTypes: [.folder],
        allowsMultipleSelection: false
    ) { result in
        handleFolderSelection(result, isSource: true)
    }

    .fileImporter(
        isPresented: $showingDestinationPicker,
        allowedContentTypes: [.folder],
        allowsMultipleSelection: false
    ) { result in
        handleFolderSelection(result, isSource: false)
    }

    .fileImporter(
        isPresented: $showingProfilePicker,
        allowedContentTypes: [.data],
        allowsMultipleSelection: false
    ) { result in
        handleFileSelection(result, isProfile: true)
    }

    .fileImporter(
        isPresented: $showingP12Picker,
        allowedContentTypes: [.data],
        allowsMultipleSelection: false
    ) { result in
        handleFileSelection(result, isProfile: false)
    }
}

    private var detailContent: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 14) {

                switch selectedPage ?? .source {

                case .source:
                    sourceSection

                case .destination:
                    destinationSection

                case .certificate:
                    certificateSection

                case .signing:
                    signingSection

                case .logs:
                    logSection
                }
            }
            .padding(16)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    // MARK: Framework

    private var sourceSection: some View {

        GroupBox {

            VStack(alignment: .leading, spacing: 12) {

                Text("서명할 Framework가 포함된 폴더를 선택합니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                pathLabel(sourceURL)

                Button {
                    showingSourcePicker = true
                } label: {
                    Label("원본 폴더 선택", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        } label: {

            Label("원본 Framework", systemImage: "shippingbox")
                .font(.headline)
        }
    }

    // MARK: Destination

    private var destinationSection: some View {

        GroupBox {

            VStack(alignment: .leading, spacing: 12) {

                Text("서명이 완료된 Framework를 저장할 위치입니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                pathLabel(destinationURL)

                Button {
                    showingDestinationPicker = true
                } label: {
                    Label("저장 폴더 선택", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        } label: {

            Label("저장 위치", systemImage: "folder.badge.checkmark")
                .font(.headline)
        }
    }

    // MARK: Certificate

    private var certificateSection: some View {

        GroupBox {

            VStack(alignment: .leading, spacing: 14) {

                fileSelectionRow(
                    title: "Provisioning Profile",
                    filename: profileURL?.lastPathComponent
                ) {
                    showingProfilePicker = true
                }

                Divider()

                fileSelectionRow(
                    title: "P12 인증서",
                    filename: p12URL?.lastPathComponent
                ) {
                    showingP12Picker = true
                }

                SecureField("P12 비밀번호", text: $password)
                    .textFieldStyle(.roundedBorder)

                Divider()

                Text("Host Bundle Identifier")
                    .font(.subheadline.weight(.medium))

                TextField(
                    "호스트 앱 Bundle ID",
                    text: $hostBundleIdentifier
                )
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        } label: {

            Label("인증서 설정", systemImage: "key.horizontal")
                .font(.headline)
        }
    }

    // MARK: Signing

    private var signingSection: some View {

        GroupBox {

            VStack(alignment: .leading, spacing: 16) {

                Toggle(
                    "실패한 작업용 복사본 자동 삭제",
                    isOn: $deleteFailedCopies
                )

                HStack(spacing: 12) {

                    resultItem(
                        title: "성공",
                        value: successCount,
                        color: .green
                    )

                    resultItem(
                        title: "실패",
                        value: failedCount,
                        color: .red
                    )
                }

                Button {
                    startSigning()
                } label: {

                    Label(
                        isSigning ? "서명 진행 중..." : "Framework 서명 시작",
                        systemImage: "checkmark.shield"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSigning || !canStartSigning)

                if isSigning {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        } label: {

            Label("서명 실행", systemImage: "signature")
                .font(.headline)
        }
    }

    // MARK: Logs

    private var logSection: some View {

        GroupBox {

            ScrollView {

                VStack(alignment: .leading, spacing: 7) {

                    ForEach(Array(logs.enumerated()), id: \.offset) { _, log in

                        Text(log)
                            .font(.system(size: 12, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(minHeight: 180, maxHeight: 450)

        } label: {

            Label("작업 로그", systemImage: "terminal")
                .font(.headline)
        }
    }

    // MARK: Components

    private func pathLabel(_ url: URL?) -> some View {

        HStack {

            Image(systemName: "folder")
                .foregroundStyle(.secondary)

            Text(url?.lastPathComponent ?? "선택된 폴더 없음")
                .font(.subheadline)
                .lineLimit(2)

            Spacer()
        }
        .padding(10)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func fileSelectionRow(
        title: String,
        filename: String?,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            HStack {

                VStack(alignment: .leading, spacing: 4) {

                    Text(title)
                        .font(.subheadline.weight(.medium))

                    Text(filename ?? "파일을 선택해 주세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: filename == nil
                      ? "plus.circle"
                      : "checkmark.circle.fill")
                    .foregroundColor(filename == nil ? .secondary : .green)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func resultItem(
        title: String,
        value: Int,
        color: Color
    ) -> some View {

        VStack(alignment: .leading, spacing: 4) {

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text("\(value)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: Validation

    private var canStartSigning: Bool {

        sourceURL != nil &&
        destinationURL != nil &&
        profileURL != nil &&
        p12URL != nil &&
        !hostBundleIdentifier.isEmpty &&
        !password.isEmpty
    }

    // MARK: File Selection

    private func handleFolderSelection(
        _ result: Result<[URL], Error>,
        isSource: Bool
    ) {

        switch result {

        case .success(let urls):

            guard let url = urls.first else { return }

            if isSource {
                sourceURL = url
                addLog("원본 폴더 선택: \(url.lastPathComponent)")
            } else {
                destinationURL = url
                addLog("저장 폴더 선택: \(url.lastPathComponent)")
            }

        case .failure(let error):

            addLog("폴더 선택 실패: \(error.localizedDescription)")
        }
    }

    private func handleFileSelection(
        _ result: Result<[URL], Error>,
        isProfile: Bool
    ) {

        switch result {

        case .success(let urls):

            guard let url = urls.first else { return }

            if isProfile {
                profileURL = url
                addLog("프로파일 선택 완료")
            } else {
                p12URL = url
                addLog("P12 인증서 선택 완료")
            }

        case .failure(let error):

            addLog("파일 선택 실패: \(error.localizedDescription)")
        }
    }

    // MARK: Signing

    private func startSigning() {

        guard
            let source = sourceURL,
            let destination = destinationURL,
            let profile = profileURL,
            let p12 = p12URL
        else {
            return
        }

        isSigning = true
        successCount = 0
        failedCount = 0

        addLog("서명 작업 시작")

        let currentPassword = password
        let currentBundleID = hostBundleIdentifier
        let shouldDelete = deleteFailedCopies

        DispatchQueue.global(qos: .userInitiated).async {

            do {

                let result = try SigningService.signFolder(
                    sourceURL: source,
                    destinationURL: destination,
                    profileURL: profile,
                    p12URL: p12,
                    password: currentPassword,
                    hostBundleIdentifier: currentBundleID,
                    deleteFailedCopies: shouldDelete
                ) { message in

                    DispatchQueue.main.async {
                        addLog(message)
                    }
                }

                DispatchQueue.main.async {

                    successCount = result.success.count
                    failedCount = result.failed.count

                    addLog("서명 작업 완료")
                    isSigning = false
                }

            } catch {

                DispatchQueue.main.async {

                    addLog("오류: \(error.localizedDescription)")
                    isSigning = false
                }
            }
        }
    }

    private func addLog(_ message: String) {

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        logs.append(
            "[\(formatter.string(from: Date()))] \(message)"
        )
    }
}
