import CreatorCore
import SwiftUI
import UniformTypeIdentifiers

@main
struct CreatorApp: App {
    private let config = AppConfiguration(arguments: ProcessInfo.processInfo.arguments)
    @StateObject private var model = CreatorViewModel()
    @State private var showAbout = false

    var body: some Scene {
        WindowGroup {
            CreatorShell(configuration: config)
                .environmentObject(model)
                .frame(minWidth: 900, minHeight: 600)
                .task { await model.load() }
                .sheet(isPresented: $showAbout) { AboutCreatorView(configuration: config) }
        }
        .commands {
            CommandGroup(replacing: .appInfo) { Button("About \(config.displayName)") { showAbout = true } }
            CommandGroup(replacing: .newItem) { Button("New research note…") { model.showNewNote = true }.keyboardShortcut("n", modifiers: .command) }
        }
    }
}

enum ThemeChoice { case neutral, pip }
struct AppConfiguration {
    let theme: ThemeChoice
    let plus: Bool
    init(arguments: [String]) {
        let info = Bundle.main.infoDictionary ?? [:]
        theme = arguments.contains("--theme=pip") || (info["PIPCreatorTheme"] as? String == "pip") ? .pip : .neutral
        plus = arguments.contains("--plus") || (info["PIPCreatorPlus"] as? Bool == true)
    }
    var displayName: String { theme == .pip ? "Pip Creator" : "Creator Studio" }
}

@MainActor final class CreatorViewModel: ObservableObject {
    @Published var videos: [CreatorVideo] = []
    @Published var selection: String?
    @Published var search = ""
    @Published var status: String?
    @Published var error: String?
    @Published var showNewNote = false
    @Published var showImporter = false
    @Published var exportFormat: ExportFormat?
    @Published var exportDocument: ExportDocument?
    @Published var showExportPreview = false
    var exportConfirmed = false
    private var exportItemCount = 0
    @Published var newTitle = ""
    @Published var newChannel = ""
    @Published var newURL = ""
    @Published var selectedIDs = Set<String>()
    @Published var sectionFilterWorkspace: String?
    @Published var workspaces: [String] = []
    @Published var workspaceMode = false

    private let store: CreatorStore
    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PipCreator", isDirectory: true).appendingPathComponent("library.json")
        store = CreatorStore(fileURL: support)
    }
    var filtered: [CreatorVideo] {
        let scoped = workspaceMode ? videos.filter { $0.workspace != nil && (sectionFilterWorkspace == nil || $0.workspace == sectionFilterWorkspace) } : videos
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return scoped }
        return scoped.filter { $0.title.localizedCaseInsensitiveContains(needle) || $0.channel.localizedCaseInsensitiveContains(needle) || $0.notes.localizedCaseInsensitiveContains(needle) }
    }
    var selected: CreatorVideo? { filtered.first { $0.id == selection } ?? filtered.first }
    func load() async { videos = await store.all(); workspaces = Array(Set(videos.compactMap(\.workspace))).sorted(); if let warning = await store.recoveryMessage { error = warning }; if selection == nil { selection = videos.first?.id } }
    func importFile(_ url: URL) async {
        do {
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            if let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > CreatorImporter.maxFileBytes { throw CreatorImportError.tooLarge }
            let values = try CreatorImporter.decode(data: Data(contentsOf: url, options: .mappedIfSafe), filename: url.lastPathComponent)
            let count = try await store.add(values)
            await load(); status = "Imported \(count) new video\(count == 1 ? "" : "s")."
            error = nil
        } catch { self.error = error.localizedDescription; status = nil }
    }
    func addNote() async {
        let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { error = "Add a title first."; return }
        let video = CreatorVideo(title: title, channel: newChannel, url: newURL, source: .manual)
        do { _ = try await store.add([video]); await load(); selection = video.id; showNewNote = false; newTitle = ""; newChannel = ""; newURL = ""; error = nil }
        catch { self.error = error.localizedDescription }
    }
    func saveWorkspace(_ id: String, _ workspace: String?) async {
        do { try await store.updateWorkspace(id: id, workspace: workspace); await load(); error = nil }
        catch { self.error = error.localizedDescription }
    }
    func saveNotes(_ id: String, _ notes: String) async {
        do { try await store.updateNotes(id: id, notes: notes); await load() }
        catch { self.error = error.localizedDescription }
    }
    func addSamples() async {
        let now = Date()
        let samples = [
            CreatorVideo(id: "sample-1", title: "A week of tiny studio upgrades", channel: "Mara Makes", url: "https://www.youtube.com/watch?v=sample000001", publishedAt: now.addingTimeInterval(-86400 * 3), capturedAt: now, source: .sample, views: 12800, likes: 930, comments: 82, notes: "Sample research item. Replace with your own observations."),
            CreatorVideo(id: "sample-2", title: "I tried a one-camera filming setup", channel: "North Window", url: "https://www.youtube.com/watch?v=sample000002", publishedAt: now.addingTimeInterval(-86400 * 10), capturedAt: now, source: .sample, views: nil, likes: nil, comments: nil, notes: "Sample metrics are illustrative, not live YouTube data."),
            CreatorVideo(id: "sample-3", title: "The quiet art of finishing a project", channel: "Mara Makes", url: "https://www.youtube.com/watch?v=sample000003", publishedAt: now.addingTimeInterval(-86400 * 21), capturedAt: now, source: .sample, views: 43200, likes: nil, comments: 410, notes: "Missing fields stay unknown; they are not treated as zero.")
        ]
        do { _ = try await store.add(samples); await load(); status = "Added clearly marked sample research."; error = nil }
        catch { self.error = error.localizedDescription }
    }
    func prepareExport(format: ExportFormat) {
        selectedIDs = Set(videos.map(\.id)); exportConfirmed = false; exportFormat = format; showExportPreview = true
    }
    func exportPreviewDidDismiss() {
        if exportConfirmed { exportConfirmed = false; beginExport() }
        else if exportDocument == nil { exportFormat = nil }
    }
    func beginExport() {
        guard let format = exportFormat, !selectedIDs.isEmpty else { return }
        let ids = selectedIDs
        exportItemCount = ids.count
        showExportPreview = false
        Task {
            do {
                let data = format == .json ? try await store.exportJSON(ids: ids) : await store.exportCSV(ids: ids)
                exportDocument = ExportDocument(data: data)
            } catch { self.error = error.localizedDescription; exportFormat = nil }
        }
    }
    func finishedExport(_ result: Result<URL, Error>) {
        switch result {
        case .success: status = "Exported \(exportItemCount) selected item\(exportItemCount == 1 ? "" : "s")."; error = nil
        case .failure(let issue): if !(issue is CancellationError) { error = issue.localizedDescription }
        }
        exportFormat = nil; exportDocument = nil
    }
}

enum ExportFormat: String, Identifiable { case csv = "CSV", json = "JSON"; var id: String { rawValue } }

struct CreatorShell: View {
    let configuration: AppConfiguration
    @EnvironmentObject private var model: CreatorViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var section = "Library"
    private var pip: Bool { configuration.theme == .pip }
    private var colors: CreatorPalette { pip ? .pip(dark: colorScheme == .dark) : .neutral }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 10) {
                    BrandMark(pip: pip).frame(width: 35, height: 35)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(configuration.displayName).font(.system(size: 16, weight: .semibold, design: .rounded))
                        Text("Local creator research").font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.horizontal, 17).padding(.top, 24)
                VStack(spacing: 3) {
                    sidebarItem("Library", icon: "rectangle.stack")
                    sidebarItem("Workspace", icon: "folder")
                    if configuration.plus && section == "Workspace" {
                        Button { model.sectionFilterWorkspace = nil } label: { Label("All workspaces", systemImage: "square.grid.2x2").font(.caption).padding(.leading, 29).padding(.vertical, 5).frame(maxWidth: .infinity, alignment: .leading).background(model.sectionFilterWorkspace == nil ? colors.selected : .clear, in: RoundedRectangle(cornerRadius: 7)) }.buttonStyle(.plain).accessibilityAddTraits(model.sectionFilterWorkspace == nil ? .isSelected : [])
                        ForEach(model.workspaces, id: \.self) { workspace in
                            Button { model.sectionFilterWorkspace = workspace; model.selection = model.videos.first { $0.workspace == workspace }?.id } label: { HStack { Text(workspace).font(.caption); Spacer(); Text("\(model.videos.filter { $0.workspace == workspace }.count)").font(.caption2).foregroundStyle(.secondary) }.padding(.leading, 29).padding(.vertical, 5).frame(maxWidth: .infinity, alignment: .leading).background(model.sectionFilterWorkspace == workspace ? colors.selected : .clear, in: RoundedRectangle(cornerRadius: 7)) }.buttonStyle(.plain).accessibilityAddTraits(model.sectionFilterWorkspace == workspace ? .isSelected : [])
                        }
                    }
                }.padding(.horizontal, 10)
                Spacer()
                VStack(alignment: .leading, spacing: 8) {
                    Label("Stored on this Mac", systemImage: "lock.fill").font(.caption.weight(.medium))
                    Text("No account connected · Offline mode").font(.caption2).foregroundStyle(.secondary)
                }.padding(14).background(colors.panel, in: RoundedRectangle(cornerRadius: 13)).padding(12)
            }
            .background(colors.sidebar)
            .navigationSplitViewColumnWidth(min: 195, ideal: 220, max: 250)
        } detail: {
            VStack(spacing: 0) {
                header
                if let error = model.error { ErrorBanner(message: error, dismiss: { model.error = nil }) }
                if let status = model.status { StatusBanner(message: status).padding(.horizontal, 22).padding(.top, 10) }
                if section == "Workspace" && !configuration.plus {
                    emptyState(title: "Workspace collections", detail: "The Plus build adds local grouping. Choose Core for the single-library workflow.")
                } else if section == "Workspace" && model.filtered.isEmpty {
                    VStack(spacing: 12) { Text("No workspace items yet").font(.system(size: 18, weight: .semibold)); Text("Open an item from your library and assign it to a workspace.").font(.callout).foregroundStyle(.secondary); Button("Open library") { section = "Library" }.buttonStyle(.borderedProminent) }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if model.videos.isEmpty {
                    emptyLibrary
                } else {
                    libraryContent
                }
            }
            .background(colors.canvas)
        }
        .tint(colors.accent)
        .fileImporter(isPresented: $model.showImporter, allowedContentTypes: [UTType.commaSeparatedText, UTType.json], allowsMultipleSelection: false) { result in
            switch result { case .success(let urls): if let url = urls.first { Task { await model.importFile(url) } }; case .failure(let issue): model.error = issue.localizedDescription }
        }
        .fileExporter(isPresented: Binding(get: { model.exportDocument != nil }, set: { if !$0 { model.exportFormat = nil; model.exportDocument = nil } }), document: model.exportDocument ?? ExportDocument(data: Data()), contentType: model.exportFormat == .csv ? .commaSeparatedText : .json, defaultFilename: "creator-research") { result in
            model.finishedExport(result)
        }
        .sheet(isPresented: $model.showNewNote) { NewNoteSheet(model: model, pip: pip) }
        .sheet(isPresented: $model.showExportPreview, onDismiss: { model.exportPreviewDidDismiss() }) { ExportPreview(model: model) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(section == "Library" ? "Research library" : "Workspace").font(.system(size: 23, weight: .semibold, design: .rounded))
                Text("Keep useful examples, sources and your own observations together.").font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Menu { Button("Export as CSV") { model.prepareExport(format: .csv) }; Button("Export as JSON") { model.prepareExport(format: .json) } } label: { Label("Export", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered).disabled(model.videos.isEmpty)
            Menu {
                Button("Import CSV or JSON…", systemImage: "tray.and.arrow.down") { model.showImporter = true }
                Button("Add research note…", systemImage: "square.and.pencil") { model.showNewNote = true }
                Divider()
                Button("Add sample library", systemImage: "sparkles") { Task { await model.addSamples() } }
            } label: { Label("Add research", systemImage: "plus").labelStyle(.titleAndIcon) }.buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
        .background(colors.canvas)
    }

    private var emptyLibrary: some View {
        VStack(spacing: 18) {
            BrandMark(pip: pip).frame(width: 68, height: 68)
            VStack(spacing: 6) {
                Text("Your research starts here").font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("Import a CSV or JSON file, add a note, or explore the clearly labelled sample library.")
                    .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 390)
            }
            HStack { Button("Import CSV or JSON") { model.showImporter = true }.buttonStyle(.borderedProminent); Button("Add sample library") { Task { await model.addSamples() } }.buttonStyle(.bordered) }
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var libraryContent: some View {
        HStack(spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 8) { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Search titles, channels and notes", text: $model.search).textFieldStyle(.plain) }
                    .padding(9).background(colors.panel, in: RoundedRectangle(cornerRadius: 9)).padding(.horizontal, 14).padding(.top, 12)
                List(selection: $model.selection) {
                    ForEach(model.filtered) { video in
                        VideoRow(video: video, pip: pip).tag(video.id)
                    }
                }.listStyle(.sidebar)
                    .onChange(of: model.filtered.map(\.id)) { _, ids in if let current = model.selection, !ids.contains(current) { model.selection = ids.first } }
                HStack { Text("\(model.filtered.count) items"); Spacer(); Text("\(model.videos.filter { $0.source == .sample }.count) samples") }
                    .font(.caption2).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.bottom, 11)
            }
            .frame(minWidth: 270, idealWidth: 330, maxWidth: 370)
            Rectangle().fill(colors.rule).frame(width: 1)
            if let video = model.selected { VideoDetail(video: video, pip: pip, canManageWorkspaces: configuration.plus, save: { notes in Task { await model.saveNotes(video.id, notes) } }, saveWorkspace: { workspace in Task { await model.saveWorkspace(video.id, workspace) } }).id(video.id) }
            else { emptyState(title: "Select a research item", detail: "Choose an item from your library to see its details.") }
        }
    }

    private func sidebarItem(_ title: String, icon: String) -> some View {
        Button { section = title; model.workspaceMode = title == "Workspace"; model.sectionFilterWorkspace = nil } label: {
            HStack(spacing: 10) { Image(systemName: icon).frame(width: 18); Text(title).font(.subheadline.weight(.medium)); Spacer(); if title == "Library" { Text("\(model.videos.count)").font(.caption2.weight(.medium)).foregroundStyle(.secondary) } }
                .padding(.horizontal, 10).padding(.vertical, 8).contentShape(RoundedRectangle(cornerRadius: 8))
                .background(section == title ? colors.selected : .clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain)
    }
    private func emptyState(title: String, detail: String) -> some View { VStack(spacing: 8) { Text(title).font(.system(size: 17, weight: .semibold)); Text(detail).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 360) }.font(.subheadline).frame(maxWidth: .infinity, maxHeight: .infinity) }
}

struct VideoRow: View {
    let video: CreatorVideo
    let pip: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(video.title).font(.callout.weight(.medium)).lineLimit(2)
            HStack(spacing: 6) {
                Text(video.channel.isEmpty ? "Untitled channel" : video.channel).lineLimit(1)
                Text("·")
                Text(video.source.rawValue)
            }.font(.caption2).foregroundStyle(.secondary)
        }.padding(.vertical, 3).accessibilityElement(children: .combine)
    }
}

struct VideoDetail: View {
    let video: CreatorVideo
    let pip: Bool
    let canManageWorkspaces: Bool
    let save: (String) -> Void
    let saveWorkspace: (String?) -> Void
    @State private var notes: String
    @State private var workspace: String
    @Environment(\.colorScheme) private var colorScheme
    init(video: CreatorVideo, pip: Bool, canManageWorkspaces: Bool, save: @escaping (String) -> Void, saveWorkspace: @escaping (String?) -> Void) { self.video = video; self.pip = pip; self.canManageWorkspaces = canManageWorkspaces; self.save = save; self.saveWorkspace = saveWorkspace; _notes = State(initialValue: video.notes); _workspace = State(initialValue: video.workspace ?? "") }
    private var palette: CreatorPalette { pip ? .pip(dark: colorScheme == .dark) : .neutral }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(video.title).font(.system(size: 23, weight: .semibold, design: .rounded)).fixedSize(horizontal: false, vertical: true)
                        Text(video.channel.isEmpty ? "Channel not provided" : video.channel).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 18)
                    Text(video.source.rawValue).font(.caption2.weight(.medium)).padding(.horizontal, 9).padding(.vertical, 5).background(palette.badge, in: Capsule())
                }
                HStack(spacing: 9) {
                    MetricTile(name: "Views", value: video.views)
                    MetricTile(name: "Likes", value: video.likes)
                    MetricTile(name: "Comments", value: video.comments)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Source details").font(.headline)
                    DetailLine(label: "Added", value: video.capturedAt.formatted(date: .abbreviated, time: .shortened))
                    DetailLine(label: "Published", value: video.publishedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Not provided")
                    if !video.url.isEmpty, let url = URL(string: video.url), url.scheme == "https" {
                        Link(destination: url) { Label("Open public video page", systemImage: "arrow.up.right.square").font(.callout) }
                    } else { DetailLine(label: "Video link", value: "Not provided") }
                }.padding(15).background(palette.panel, in: RoundedRectangle(cornerRadius: 12))
                if canManageWorkspaces {
                    VStack(alignment: .leading, spacing: 9) {
                        Text("Workspace").font(.headline)
                        TextField("Workspace name", text: $workspace).textFieldStyle(.roundedBorder)
                        HStack { if !workspace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { Button("Remove from workspace") { workspace = ""; saveWorkspace(nil) }.buttonStyle(.bordered) }; Spacer(); Button("Save workspace") { let cleaned = workspace.trimmingCharacters(in: .whitespacesAndNewlines); workspace = cleaned; saveWorkspace(cleaned.isEmpty ? nil : cleaned) }.buttonStyle(.borderedProminent) }
                    }.padding(15).background(palette.panel, in: RoundedRectangle(cornerRadius: 12))
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text("Your notes").font(.headline); Spacer(); Button("Save notes") { save(notes) }.buttonStyle(.bordered).controlSize(.small) }
                    TextEditor(text: $notes).font(.callout).frame(minHeight: 105).scrollContentBackground(.hidden).padding(6).background(palette.canvas, in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.rule))
                }
                if video.source == .sample { Text("Illustrative sample only. These values are not live YouTube data.").font(.caption).foregroundStyle(.secondary) }
                Spacer(minLength: 24)
            }.padding(22).frame(maxWidth: 760, alignment: .leading)
        }
    }
}

struct MetricTile: View {
    let name: String
    let value: Int64?
    var body: some View {
        VStack(alignment: .leading, spacing: 5) { Text(name).font(.caption2).foregroundStyle(.secondary); Text(value.map { NumberFormatter.localizedString(from: NSNumber(value: $0), number: .decimal) } ?? "Unknown").font(.system(size: 17, weight: .semibold, design: .rounded)) }
            .frame(maxWidth: .infinity, alignment: .leading).padding(12).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }
}
struct DetailLine: View { let label: String; let value: String; var body: some View { HStack(alignment: .firstTextBaseline) { Text(label).foregroundStyle(.secondary).frame(width: 90, alignment: .leading); Text(value).textSelection(.enabled); Spacer() }.font(.callout) } }

struct NewNoteSheet: View {
    @ObservedObject var model: CreatorViewModel
    let pip: Bool
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Add research note").font(.system(size: 19, weight: .semibold, design: .rounded))
            Text("Keep your own observation or a link to review later.").font(.callout).foregroundStyle(.secondary)
            TextField("Video or idea title", text: $model.newTitle)
            TextField("Channel or creator (optional)", text: $model.newChannel)
            TextField("Public URL (optional)", text: $model.newURL)
            if let error = model.error { Text(error).font(.caption).foregroundStyle(.red) }
            HStack { Spacer(); Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction); Button("Save note") { Task { await model.addNote(); if !model.showNewNote { dismiss() } } }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent) }
        }.padding(24).frame(width: 440)
    }
}


struct AboutCreatorView: View {
    let configuration: AppConfiguration
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 12) {
            BrandMark(pip: configuration.theme == .pip).frame(width: 58, height: 58)
            Text(configuration.displayName).font(.title2.weight(.semibold))
            Text(configuration.plus ? "Plus · local workspace collections" : "Core · local research library").font(.subheadline).foregroundStyle(.secondary)
            Text("Version 0.1.0-alpha.1 · macOS").font(.caption).foregroundStyle(.secondary)
            Divider()
            Text("Research is stored on this Mac. This alpha makes no network requests and has no AI provider setup. No video is uploaded by the app.")
                .font(.callout).multilineTextAlignment(.center).frame(maxWidth: 340)
            Button("Close") { dismiss() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent)
        }.padding(26).frame(width: 420)
    }
}

struct ErrorBanner: View { let message: String; let dismiss: () -> Void; var body: some View { HStack { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red); Text(message).font(.callout); Spacer(); Button("Dismiss", action: dismiss).font(.caption) }.padding(11).background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 9)).padding(.horizontal, 22).padding(.top, 10) } }
struct StatusBanner: View { let message: String; var body: some View { Label(message, systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).padding(9).background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8)) } }


struct ExportPreview: View {
    @ObservedObject var model: CreatorViewModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("Export research").font(.system(size: 19, weight: .semibold, design: .rounded))
            Text("Choose exactly which items to include as \(model.exportFormat?.rawValue ?? "data"). This app does not upload exports. Choose where to save the file.").font(.callout).foregroundStyle(.secondary)
            Text("\(model.selectedIDs.count) of \(model.videos.count) items selected").font(.caption.weight(.medium))
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(model.videos) { video in
                        Toggle(isOn: Binding(get: { model.selectedIDs.contains(video.id) }, set: { checked in if checked { model.selectedIDs.insert(video.id) } else { model.selectedIDs.remove(video.id) } })) {
                            VStack(alignment: .leading, spacing: 2) { Text(video.title).font(.callout.weight(.medium)); Text("\(video.channel.isEmpty ? "No channel" : video.channel) · \(video.source.rawValue)").font(.caption2).foregroundStyle(.secondary) }
                        }.toggleStyle(.checkbox).padding(.vertical, 3)
                    }
                }
            }.frame(maxHeight: 310)
            Text("Fields: id, title, channel, url, published_at, captured_at, source, views, likes, comments, workspace, notes.").font(.caption2).foregroundStyle(.secondary)
            HStack { Button("Select all") { model.selectedIDs = Set(model.videos.map(\.id)) }.buttonStyle(.bordered); Button("Select none") { model.selectedIDs.removeAll() }.buttonStyle(.bordered); Spacer(); Button("Cancel") { model.exportConfirmed = false; model.exportFormat = nil; dismiss() }.keyboardShortcut(.cancelAction); Button("Choose save location…") { model.exportConfirmed = true; dismiss() }.keyboardShortcut(.defaultAction).buttonStyle(.borderedProminent).disabled(model.selectedIDs.isEmpty) }
        }.padding(22).frame(width: 520, height: 480)
    }
}

struct ExportDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .commaSeparatedText] }
    var data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

struct CreatorPalette {
    let canvas: Color; let sidebar: Color; let panel: Color; let accent: Color; let rule: Color; let selected: Color; let badge: Color
    static let neutral = CreatorPalette(canvas: Color(nsColor: .windowBackgroundColor), sidebar: Color(nsColor: .underPageBackgroundColor), panel: Color(nsColor: .controlBackgroundColor), accent: Color.primary, rule: Color.primary.opacity(0.12), selected: Color.primary.opacity(0.08), badge: Color.primary.opacity(0.08))
    static func pip(dark: Bool) -> CreatorPalette {
        if dark { return CreatorPalette(canvas: Color(hex: 0x0F0F0E), sidebar: Color(hex: 0x171716), panel: Color(hex: 0x212120), accent: Color(hex: 0xF1F1EE), rule: Color(hex: 0x3C3C3B), selected: Color(hex: 0x2C2C2B), badge: Color(hex: 0x3C3C3B)) }
        return CreatorPalette(canvas: Color(hex: 0xFFFFFF), sidebar: Color(hex: 0xFAFAFA), panel: Color(hex: 0xF3F3F3), accent: Color(hex: 0x121211), rule: Color(hex: 0xDEDEDE), selected: Color(hex: 0xEBEBEB), badge: Color(hex: 0xEBEBEB))
    }
}
struct BrandMark: View {
    let pip: Bool
    var body: some View {
        Group {
            if pip { PipMark() }
            else { ZStack { Circle().fill(Color.accentColor); Image(systemName: "chart.bar.xaxis").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white) }.accessibilityLabel("Creator research") }
        }
    }
}
struct PipMark: View {
    var body: some View {
        ZStack {
            Circle().fill(Color(hex: 0x121211))
            Ellipse().fill(Color(hex: 0xE3F84B)).frame(width: 21, height: 15).offset(y: 3)
            HStack(spacing: 6) { Circle().fill(Color(hex: 0x121211)).frame(width: 2.7, height: 3.5); Circle().fill(Color(hex: 0x121211)).frame(width: 2.7, height: 3.5) }.offset(y: 1)
            Capsule().fill(Color(hex: 0x121211)).frame(width: 14, height: 1.4).offset(y: 18)
        }.accessibilityLabel("Pip mark")
    }
}
extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1) }
}
