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

        case .source:
            return "shippingbox"

        case .destination:
            return "folder.badge.checkmark"

        case .certificate:
            return "key.horizontal"

        case .signing:
            return "signature"

        case .logs:
            return "terminal"
        }
    }
}

struct ContentView: View {

    @State private var selectedPage: SignerPage = .source

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

    @State private var currentFile = ""
    @State private var progressText = ""

    @State private var progressValue = 0.0

    @State private var successCount = 0
    @State private var failedCount = 0
    @State private var skippedCount = 0

    var body: some View {

        NavigationView {

            HStack(spacing: 0) {

                sidebar

                Divider()

                detailContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
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

    // MARK: Sidebar

    private var sidebar: some View {

        VStack(alignment: .leading, spacing: 7) {

            Text("NX2Apple")
                .font(.title3.bold())
                .padding(.horizontal, 12)
                .padding(.top, 18)
                .padding(.bottom, 12)

            ForEach(SignerPage.allCases) { page in

                Button {

                    selectedPage = page

                } label: {

                    HStack(spacing: 10) {

                        Image(systemName: page.icon)
                            .frame(width: 23)

                        Text(page.rawValue)
                            .font(.system(size: 14))

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 13)
                    .foregroundColor(
                        selectedPage == page ? .blue : .primary
                    )
                    .background(
                        selectedPage == page
                        ? Color.blue.opacity(0.13)
                        : Color.clear
                    )
                    .clipShape(
                        RoundedRectangle(cornerRadius: 9)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 7)
        .frame(width: 160)
        .background(
            Color(uiColor: .secondarySystemGroupedBackground)
        )
    }

    // MARK: Detail

    private var detailContent: some View {

        ScrollView {

            VStack(alignment: .leading, spacing: 15) {

                switch selectedPage {

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
        .background(
            Color(uiColor: .systemGroupedBackground)
        )
    }

    // MARK: Source

    private var sourceSection: some View {

        GroupBox {

            VStack(alignment: .leading, spacing: 13) {

                Text("서명할 Framework가 포함된 원본 폴더입니다.")
                    .foregroundColor(.secondary)

                pathLabel(sourceURL)

                Button {

                    showingSourcePicker = true

                } label: {

                    Label(
                        "원본 폴더 선택",
                        systemImage: "folder"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        } label: {

            Label(
                "원본 Framework",
                systemImage: "shippingbox"
            )
        }
    }

    // MARK: Destination

    private var destinationSection: some View {

        GroupBox {

            VStack(alignment: .leading, spacing: 13) {

                Text("서명이 완료된 Framework를 저장할 위치입니다.")
                    .foregroundColor(.secondary)

                pathLabel(destinationURL)

                Button {

                    showingDestinationPicker = true

                } label: {

                    Label(
                        "저장 폴더 선택",
                        systemImage: "folder.badge.plus"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        } label: {

            Label(
                "저장 위치",
                systemImage: "folder.badge.checkmark"
            )
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

                SecureField(
                    "P12 비밀번호",
                    text: $password
                )
                .textFieldStyle(.roundedBorder)

                Divider()

                Text("Host Bundle Identifier")

                TextField(
                    "호스트 앱 Bundle ID",
                    text: $hostBundleIdentifier
                )
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }

        } label: {

            Label(
                "인증서 설정",
                systemImage: "key.horizontal"
            )
        }
    }

    // MARK: Signing

    private var signingSection: some View {

        GroupBox {

            VStack(alignment: .leading, spacing: 15) {

                Toggle(
                    "실패한 작업용 복사본 자동 삭제",
                    isOn: $deleteFailedCopies
                )

                HStack {

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

                    resultItem(
                        title: "스킵",
                        value: skippedCount,
                        color: .secondary
                    )
                }

                Divider()

                Text("현재 처리 파일")
                    .font(.subheadline.bold())

                Text(
                    currentFile.isEmpty
                    ? "대기 중"
                    : currentFile
                )
                .font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled)

                Text(progressText)
                    .font(.caption)
                    .foregroundColor(.secondary)

                ProgressView(value: progressValue)

                Button {

                    startSigning()

                } label: {

                    Label(
                        isSigning ? "작업 진행 중..." : "서명 시작",
                        systemImage: "checkmark.shield"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSigning || !canStartSigning)

                if !canStartSigning && !isSigning {

                    Text("원본, 저장 위치, 인증서, 프로파일 및 Bundle ID를 확인해 주세요.")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                if isSigning {

                    ProgressView()
                }
            }

        } label: {

            Label(
                "서명 실행",
                systemImage: "signature"
            )
        }
    }

    // MARK: Logs

    private var logSection: some View {

        GroupBox {

            VStack(alignment: .leading, spacing: 10) {

                HStack {

                    Text("작업 기록")

                    Spacer()

                    Button("로그 지우기") {

                        logs.removeAll()
                    }
                    .disabled(isSigning)
                }

                Divider()

                ScrollView {

                    VStack(alignment: .leading, spacing: 7) {

                        ForEach(
                            Array(logs.enumerated()),
                            id: \.offset
                        ) { _, line in

                            Text(line)
                                .font(
                                    .system(
                                        size: 12,
                                        design: .monospaced
                                    )
                                )
                                .textSelection(.enabled)
                                .frame(
                                    maxWidth: .infinity,
                                    alignment: .leading
                                )
                        }
                    }
                }
                .frame(minHeight: 250)
            }

        } label: {

            Label(
                "작업 로그",
                systemImage: "terminal"
            )
        }
    }

    // MARK: Components

    private func pathLabel(_ url: URL?) -> some View {

        HStack {

            Image(systemName: "folder")
                .foregroundColor(.secondary)

            Text(
                url?.lastPathComponent ?? "선택된 폴더 없음"
            )
            .lineLimit(2)

            Spacer()
        }
        .padding(11)
        .background(
            Color(uiColor: .tertiarySystemGroupedBackground)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 9)
        )
    }

    private func fileSelectionRow(
        title: String,
        filename: String?,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            HStack {

                VStack(alignment: .leading, spacing: 5) {

                    Text(title)

                    Text(
                        filename ?? "파일을 선택해 주세요"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }

                Spacer()

                Image(
                    systemName: filename == nil
                    ? "plus.circle"
                    : "checkmark.circle.fill"
                )
                .foregroundColor(
                    filename == nil ? .secondary : .green
                )
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

        VStack(alignment: .leading, spacing: 5) {

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text("\(value)")
                .font(.title2.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            Color(uiColor: .tertiarySystemGroupedBackground)
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 9)
        )
    }

    // MARK: Validation

    private var canStartSigning: Bool {

        sourceURL != nil &&
        destinationURL != nil &&
        profileURL != nil &&
        p12URL != nil &&
        !hostBundleIdentifier.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty &&
        !password.isEmpty
    }

    // MARK: Folder Selection

    private func handleFolderSelection(
        _ result: Result<[URL], Error>,
        isSource: Bool
    ) {

        switch result {

        case .success(let urls):

            guard let url = urls.first else {
                return
            }

            if isSource {

                sourceURL = url
                addLog("원본 폴더 선택: \(url.lastPathComponent)")

            } else {

                destinationURL = url
                addLog("저장 위치 선택: \(url.lastPathComponent)")
            }

        case .failure(let error):

            addLog("폴더 선택 실패: \(error.localizedDescription)")
        }
    }

    // MARK: File Selection

    private func handleFileSelection(
        _ result: Result<[URL], Error>,
        isProfile: Bool
    ) {

        switch result {

        case .success(let urls):

            guard let url = urls.first else {
                return
            }

            if isProfile {

                profileURL = url
                addLog("프로파일 선택: \(url.lastPathComponent)")

            } else {

                p12URL = url
                addLog("P12 선택: \(url.lastPathComponent)")
            }

        case .failure(let error):

            addLog("파일 선택 실패: \(error.localizedDescription)")
        }
    }

    // MARK: Start Signing

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

        progressValue = 0
        successCount = 0
        failedCount = 0
        skippedCount = 0

        currentFile = "작업 준비 중"
        progressText = "인증서 검증 중"

        let currentPassword = password
        let currentBundleID = hostBundleIdentifier
        let shouldDelete = deleteFailedCopies

        addLog("서명 작업 시작")

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

                        if message.hasPrefix("FILE:") {

                            currentFile = String(
                                message.dropFirst(5)
                            )
                        }

                        if message.hasPrefix("PROGRESS:") {

                            let values = message
                                .dropFirst(9)
                                .split(separator: "/")

                            if values.count == 2,
                               let done = Double(values[0]),
                               let total = Double(values[1]),
                               total > 0 {

                                progressValue = done / total

                                progressText =
                                    "\(Int(done))/\(Int(total))"
                            }
                        }
                    }
                }

                DispatchQueue.main.async {

                    successCount = result.success.count
                    failedCount = result.failed.count
                    skippedCount = result.skipped.count

                    progressValue = 1
                    currentFile = "작업 완료"
                    progressText = "전체 작업 완료"

                    addLog("전체 작업 완료")

                    isSigning = false
                }

            } catch {

                DispatchQueue.main.async {

                    currentFile = "작업 실패"
                    progressText = error.localizedDescription

                    addLog(
                        "오류: \(error.localizedDescription)"
                    )

                    isSigning = false
                }
            }
        }
    }

    // MARK: Log

    private func addLog(_ message: String) {

        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"

        logs.append(
            "[\(formatter.string(from: Date()))] \(message)"
        )
    }
}
