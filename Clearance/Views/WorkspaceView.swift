import SwiftUI

struct WorkspaceView: View {
    @StateObject private var viewModel = WorkspaceViewModel()

    var body: some View {
        NavigationSplitView {
            RecentFilesSidebar(entries: viewModel.recentFilesStore.entries) { entry in
                viewModel.open(recentEntry: entry)
            }
            .navigationTitle("Open Files")
        } detail: {
            Group {
                if let session = viewModel.activeSession {
                    let parsed = FrontmatterParser().parse(markdown: session.content)
                    RenderedMarkdownView(document: parsed)
                } else {
                    ContentUnavailableView("Open a Markdown File", systemImage: "doc.text")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Open") {
                    viewModel.promptAndOpenFile()
                }
            }
        }
        .alert("Could Not Open File", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.errorMessage = nil
                }
            }
        ), actions: {
            Button("OK", role: .cancel) {
                viewModel.errorMessage = nil
            }
        }, message: {
            Text(viewModel.errorMessage ?? "")
        })
    }
}
