
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {

    @State private var showingFrameworkPicker = false
    @State private var frameworkURL: URL?
    @State private var statusMessage = "프레임워크를 선택해 주세요."

    var body: some View {
        NavigationView {
            VStack(spacing: 22) {

                Image(systemName: "signature")
                    .font(.system(size: 54))
                    .foregroundColor(.blue)

                Text("Framework Signer")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("iOS Framework Code Signing")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: 10) {
                    Text("선택된 프레임워크")
                        .font(.headline)

                    Text(frameworkURL?.lastPathComponent ?? "선택된 폴더 없음")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(12)

                Button {
                    showingFrameworkPicker = true
                } label: {
                    Label("Framework 폴더 선택", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }

                Text(statusMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding()
            .navigationTitle("FrameworkSigner")
            .fileImporter(
                isPresented: $showingFrameworkPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    frameworkURL = url
                    statusMessage = "프레임워크 폴더를 선택했습니다."

                case .failure(let error):
                    statusMessage = "선택 실패: \(error.localizedDescription)"
                }
            }
        }
    }
}
