import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    @State private var showingFrameworkPicker = false
    @State private var showingP12Picker = false
    @State private var showingProfilePicker = false

    @State private var frameworkURL: URL?
    @State private var p12URL: URL?
    @State private var profileURL: URL?

    @State private var password = ""
    @State private var hostBundleID = ""

    @State private var isSigning = false
    @State private var statusMessage = "서명할 Framework를 선택해 주세요."
    @State private var logs: [String] = []

    var body: some View {

        NavigationView {

            ScrollView {

                VStack(spacing: 20) {

                    Image(systemName: "signature")
                        .font(.system(size: 55))
                        .foregroundColor(.blue)
                        .padding(.top, 20)

                    Text("Framework Signer")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("iOS Framework Code Signing")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    // Framework 선택

                    selectionSection(
                        title: "Framework",
                        filename: frameworkURL?.lastPathComponent,
                        buttonTitle: "Framework 폴더 선택",
                        icon: "folder"
                    ) {
                        showingFrameworkPicker = true
                    }

                    // P12 선택

                    selectionSection(
                        title: "P12 인증서",
                        filename: p12URL?.lastPathComponent,
                        buttonTitle: "P12 인증서 선택",
                        icon: "key"
                    ) {
                        showingP12Picker = true
                    }

                    // Provision 선택

                    selectionSection(
                        title: "MobileProvision",
                        filename: profileURL?.lastPathComponent,
                        buttonTitle: "프로비저닝 프로파일 선택",
                        icon: "doc.badge.gearshape"
                    ) {
                        showingProfilePicker = true
                    }

                    // P12 비밀번호

                    VStack(alignment: .leading, spacing: 8) {

                        Text("P12 비밀번호")
                            .font(.headline)

                        SecureField("인증서 비밀번호", text: $password)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 호스트 Bundle ID

                    VStack(alignment: .leading, spacing: 8) {

                        Text("NX2Apple Bundle ID")
                            .font(.headline)

                        TextField(
                            "호스트 앱 Bundle ID 입력",
                            text: $hostBundleID
                        )
                        .textFieldStyle(.roundedBorder)

                        Text("NX2Apple 앱의 실제 Bundle ID를 입력해야 합니다.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    // 서명 버튼

                    Button {

                        startSigning()

                    } label: {

                        HStack {

                            if isSigning {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "signature")
                            }

                            Text(isSigning ? "서명 진행 중..." : "Framework 서명 시작")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isSigning ? Color.gray : Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isSigning || !canSign)

                    // 상태

                    VStack(alignment: .leading, spacing: 8) {

                        Text("작업 상태")
                            .font(.headline)

                        Text(statusMessage)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)

                    // 로그

                    VStack(alignment: .leading, spacing: 8) {

                        HStack {
                            Text("작업 로그")
                                .font(.headline)

                            Spacer()

                            Button("지우기") {
                                logs.removeAll()
                            }
                            .font(.caption)
                        }

                        ForEach(Array(logs.enumerated()), id: \.offset) { _, log in

                            Text(log)
                                .font(.system(.caption, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(12)

                }
                .padding()
            }
            .navigationTitle("FrameworkSigner")
            .navigationBarTitleDisplayMode(.inline)

            // Framework 선택기

            .fileImporter(
                isPresented: $showingFrameworkPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in

                handleSelection(result) { url in
                    frameworkURL = url
                    addLog("Framework 선택: \(url.lastPathComponent)")
                }
            }

            // P12 선택기

            .fileImporter(
                isPresented: $showingP12Picker,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in

                handleSelection(result) { url in
                    p12URL = url
                    addLog("P12 선택: \(url.lastPathComponent)")
                }
            }

            // MobileProvision 선택기

            .fileImporter(
                isPresented: $showingProfilePicker,
                allowedContentTypes: [.data],
                allowsMultipleSelection: false
            ) { result in

                handleSelection(result) { url in
                    profileURL = url
                    addLog("MobileProvision 선택: \(url.lastPathComponent)")
                }
            }
        }
    }

    private var canSign: Bool {

        frameworkURL != nil &&
        p12URL != nil &&
        profileURL != nil &&
        !password.isEmpty &&
        !hostBundleID.isEmpty
    }

    // 선택 화면

    private func selectionSection(
        title: String,
        filename: String?,
        buttonTitle: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {

        VStack(alignment: .leading, spacing: 10) {

            Text(title)
                .font(.headline)

            Text(filename ?? "선택된 파일 없음")
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Button(action: action) {

                Label(buttonTitle, systemImage: icon)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.12))
                    .foregroundColor(.blue)
                    .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // 파일 선택 결과 처리

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

            statusMessage = "파일 선택 실패: \(error.localizedDescription)"
            addLog("선택 실패: \(error.localizedDescription)")
        }
    }

    // 로그 추가

    private func addLog(_ message: String) {

        logs.append("[\(Date().formatted(date: .omitted, time: .standard))] \(message)")
    }

    // 서명 시작

    private func startSigning() {

        guard
            let framework = frameworkURL,
            let p12 = p12URL,
            let profile = profileURL
        else {
            return
        }

        let currentPassword = password
        let currentBundleID = hostBundleID

        isSigning = true
        statusMessage = "Framework 서명을 시작합니다."

        addLog("서명 작업 시작")

        Task {

            do {

                try await Task.detached {

                    try SigningService.signFramework(
                        frameworkURL: framework,
                        profileURL: profile,
                        p12URL: p12,
                        password: currentPassword,
                        hostBundleIdentifier: currentBundleID
                    )

                }.value

                statusMessage = "Framework 서명이 완료되었습니다."
                addLog("서명 성공")

            } catch {

                statusMessage = "서명 실패: \(error.localizedDescription)"
                addLog("오류: \(error.localizedDescription)")
            }

            isSigning = false
        }
    }
}
