import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

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
        "NX2Apple Signer 준비 완료",
        "서명할 Framework를 선택해 주세요."
    ]

    @State private var successCount = 0
    @State private var failedCount = 0

    var body: some View {

        GeometryReader { geometry in

            let isWide = geometry.size.width >= 700

            ZStack {

                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                ScrollView {

                    VStack(spacing: 20) {

                        header

                        if isWide {

                            HStack(alignment: .top, spacing: 18) {

                                VStack(spacing: 18) {
                                    sourceSection
                                    destinationSection
                                }
                                .frame(maxWidth: .infinity)

                                VStack(spacing: 18) {
                                    certificateSection
                                    signingSection
                                }
                                .frame(maxWidth: .infinity)
                            }

                        } else {

                            sourceSection
                            destinationSection
                            certificateSection
                            signingSection
                        }

                        logSection

                        footer
                    }
                    .padding(isWide ? 24 : 16)
                    .frame(maxWidth: 1100)
                    .frame(maxWidth: .infinity)
                }
            }
        }

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

    // MARK: - Header

    private var header: some View {

        HStack(spacing: 14) {

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 34))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 4) {

                Text("NX2Apple Signer")
                    .font(.system(size: 27, weight: .bold))

                Text("Framework Signing Manager")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "iphone.gen3")
                .font(.system(size: 25))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Source

    private var sourceSection: some View {

        card(title: "원본 Framework", icon: "folder.badge.plus") {

            Text("서명할 Framework가 들어 있는 폴더를 선택합니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            pathLabel(sourceURL)

            Button {
                showingSourcePicker = true
            } label: {
                Label("원본 폴더 선택", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Destination

    private var destinationSection: some View {

        card(title: "저장 위치", icon: "folder.badge.checkmark") {

            Text("서명이 완료된 Framework를 복사할 위치입니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            pathLabel(destinationURL)

            Button {
                showingDestinationPicker = true
            } label: {
                Label("저장 폴더 선택", systemImage: "folder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Certificate

    private var certificateSection: some View {

        card(title: "인증서 설정", icon: "person.badge.key.fill") {

            VStack(alignment: .leading, spacing: 12) {

                Text("Provisioning Profile")
                    .font(.subheadline.weight(.medium))

                fileButton(
                    title: "프로파일 선택",
                    selected: profileURL != nil
                ) {
                    showingProfilePicker = true
                }

                Text("P12 인증서")
                    .font(.subheadline.weight(.medium))

                fileButton(
                    title: "P12 파일 선택",
                    selected: p12URL != nil
                ) {
                    showingP12Picker = true
                }

                SecureField("P12 비밀번호", text: $password)
                    .textFieldStyle(.roundedBorder)

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
        }
    }

    // MARK: - Signing

    private var signingSection: some View {

        card(title: "서명 실행", icon: "signature") {

            Toggle(
                "실패한 작업용 복사본 자동 삭제",
                isOn: $deleteFailedCopies
            )

            HStack(spacing: 12) {

                resultBox(
                    title: "성공",
                    value: successCount,
                    color: .green
                )

                resultBox(
                    title: "실패",
                    value: failedCount,
                    color: .red
                )
            }

            Button {
                startSigning()
            } label: {

                HStack {

                    if isSigning {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "checkmark.shield.fill")
                    }

                    Text(isSigning ? "서명 진행 중..." : "Framework 서명 시작")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSigning || !canStartSigning)
        }
    }

    // MARK: - Logs

    private var logSection: some View {

        card(title: "작업 로그", icon: "terminal") {

            ScrollView {

                VStack(alignment: .leading, spacing: 8) {

                    ForEach(Array(logs.enumerated()), id: \.offset) { _, log in

                        HStack(alignment: .top, spacing: 8) {

                            Image(systemName: "chevron.right")
                                .foregroundStyle(.blue)

                            Text(log)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 130, maxHeight: 220)
        }
    }

    // MARK: - Footer

    private var footer: some View {

        Text("NX2Apple Signer · Framework Signing Tool")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
    }

    // MARK: - Components

    private func card<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {

        VStack(alignment: .leading, spacing: 16) {

            Label(title, systemImage: icon)
                .font(.headline)

            content()
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func pathLabel(_ url: URL?) -> some View {

        Text(url?.lastPathComponent ?? "선택된 폴더가 없습니다.")
            .font(.caption)
            .foregroundStyle(url == nil ? .secondary : .primary)
            .lineLimit(2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func fileButton(
        title: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {

        Button(action: action) {

            HStack {

                Image(systemName: selected ? "checkmark.circle.fill" : "doc.badge.plus")

                Text(selected ? "파일 선택 완료" : title)

                Spacer()

                Image(systemName: "chevron.right")
            }
            .font(.subheadline)
            .padding(12)
            .background(Color(uiColor: .tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func resultBox(
        title: String,
        value: Int,
        color: Color
    ) -> some View {

        VStack(spacing: 5) {

            Text("\(value)")
                .font(.title2.bold())
                .foregroundStyle(color)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Color(uiColor: .tertiarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Validation

    private var canStartSigning: Bool {

        sourceURL != nil &&
        destinationURL != nil &&
        profileURL != nil &&
        p12URL != nil &&
        !hostBundleIdentifier.isEmpty &&
        !password.isEmpty
    }

    // MARK: - File Selection

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

    // MARK: - Signing

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

        addLog("서명 작업을 시작합니다.")

        DispatchQueue.global(qos: .userInitiated).async {

            do {

                let result = try SigningService.signFolder(
                    sourceURL: source,
                    destinationURL: destination,
                    profileURL: profile,
                    p12URL: p12,
                    password: password,
                    hostBundleIdentifier: hostBundleIdentifier,
                    deleteFailedCopies: deleteFailedCopies
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

        logs.append("[\(formatter.string(from: Date()))] \(message)")
    }
}
