import SwiftUI

struct SettingsView: View {
    @AppStorage(AppConstants.downloadFolderKey) private var downloadFolder = AppConstants.defaultDownloadFolder
    @AppStorage(AppConstants.unpaywallEmailKey) private var unpaywallEmail = ""
    @AppStorage(AppConstants.maxConcurrentDownloadsKey) private var maxConcurrent = AppConstants.defaultMaxConcurrentDownloads
    @AppStorage(AppConstants.maxSearchResultsKey) private var maxSearchResults = AppConstants.defaultMaxSearchResults
    @State private var scihubMirrors: [String] = UserDefaults.standard.stringArray(forKey: AppConstants.scihubMirrorsKey) ?? AppConstants.defaultScihubMirrors
    @State private var newMirror = ""
    @State private var mirrorStatus: [String: MirrorHealth] = [:]
    @State private var isCheckingMirrors = false
    @State private var hotkeyCombination = HotkeyCombination.load()
    @State private var quickActionInstalled = QuickActionInstaller.isInstalled
    @State private var quickActionError: String?

    // AI Settings
    @StateObject private var aiService = AIService.shared
    @State private var isInstallingOllama = false
    @State private var ollamaInstallProgress = 0.0
    @State private var isPullingModel = false
    @State private var modelPullProgress = 0.0
    @State private var selectedModel = "qwen2.5:1.5b"
    @State private var localModels: [String] = []
    @State private var aiError: String?

    enum MirrorHealth {
        case checking, reachable, unreachable
    }

    @AppStorage(AppConstants.searchEngineKey) private var searchEngineRaw = SearchEngine.pubmed.rawValue

    var body: some View {
        TabView {
            // General
            Form {
                Section("Search Engine") {
                    Picker("Default search engine", selection: $searchEngineRaw) {
                        ForEach(SearchEngine.allCases) { engine in
                            HStack {
                                Label(engine.rawValue, systemImage: engine.icon)
                                Text("— \(engine.description)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .tag(engine.rawValue)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    Text("PubMed is recommended for biomedical research. CrossRef covers broader academic fields.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Download Location") {
                    HStack {
                        TextField("Download folder", text: $downloadFolder)
                            .textFieldStyle(.roundedBorder)
                        Button("Browse...") { chooseFolder() }
                    }
                }

                Section("Unpaywall") {
                    TextField("Email (required for Unpaywall API)", text: $unpaywallEmail)
                        .textFieldStyle(.roundedBorder)
                    Text("Unpaywall requires an email address for API access. Your email is only sent to Unpaywall.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Performance") {
                    Stepper("Max concurrent downloads: \(maxConcurrent)", value: $maxConcurrent, in: 1...10)
                    Stepper("Max search results: \(maxSearchResults)", value: $maxSearchResults, in: 10...200, step: 10)
                    Text("API limits: PubMed \(AppConstants.maxResultsPubMed), CrossRef \(AppConstants.maxResultsCrossRef), Semantic Scholar \(AppConstants.maxResultsSemanticScholar), OpenAlex \(AppConstants.maxResultsOpenAlex). Your setting is clamped to each API's max.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Global Hotkey") {
                    HStack {
                        Text("Search selected text:")
                        Spacer()
                        HotkeyRecorderView(combination: $hotkeyCombination)
                    }
                    Text("Press the shortcut field, then press your desired key combination. Requires at least one modifier (⌘, ⌃, or ⌥). The hotkey copies selected text from any app and opens RefSeek to search it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Right-Click Quick Action") {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: quickActionInstalled ? "checkmark.circle.fill" : "circle.dashed")
                                    .foregroundStyle(quickActionInstalled ? .green : .secondary)
                                Text(quickActionInstalled ? "\"Search in RefSeek\" is installed" : "Not installed")
                                    .fontWeight(.medium)
                            }
                            Text("Adds \"Search in RefSeek\" to the right-click → Services menu in all apps.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if quickActionInstalled {
                            Button("Uninstall") {
                                do {
                                    try QuickActionInstaller.uninstall()
                                    quickActionInstalled = false
                                    quickActionError = nil
                                } catch {
                                    quickActionError = error.localizedDescription
                                }
                            }
                            .buttonStyle(.bordered)
                        } else {
                            Button("Install Quick Action") {
                                do {
                                    try QuickActionInstaller.install()
                                    quickActionInstalled = true
                                    quickActionError = nil
                                } catch {
                                    quickActionError = error.localizedDescription
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    if let error = quickActionError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Text("After installing, select text in any app → right-click → Services → \"Search in RefSeek\". You may need to log out/in or enable it in System Settings → Keyboard → Keyboard Shortcuts → Services → Text.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tabItem { Label("General", systemImage: "gear") }

            // Sci-Hub Mirrors
            Form {
                Section("Sci-Hub Mirrors") {
                    ForEach(Array(scihubMirrors.enumerated()), id: \.offset) { index, mirror in
                        HStack {
                            // Health indicator
                            if let status = mirrorStatus[mirror] {
                                switch status {
                                case .checking:
                                    ProgressView().controlSize(.mini)
                                        .frame(width: 16)
                                case .reachable:
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                case .unreachable:
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.red)
                                        .font(.caption)
                                }
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                                    .font(.caption)
                            }

                            Text(mirror)
                                .font(.system(.body, design: .monospaced))
                                .foregroundStyle(mirrorStatus[mirror] == .unreachable ? .secondary : .primary)
                            Spacer()
                            Button {
                                scihubMirrors.remove(at: index)
                                saveMirrors()
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        TextField("https://sci-hub.example", text: $newMirror)
                            .textFieldStyle(.roundedBorder)
                        Button {
                            let url = newMirror.trimmingCharacters(in: .whitespaces)
                            guard !url.isEmpty else { return }
                            scihubMirrors.append(url)
                            saveMirrors()
                            newMirror = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                        }
                        .disabled(newMirror.isEmpty)
                    }

                    HStack {
                        Button("Reset to Defaults") {
                            scihubMirrors = AppConstants.defaultScihubMirrors
                            mirrorStatus = [:]
                            saveMirrors()
                        }

                        Spacer()

                        Button {
                            Task { await checkMirrors() }
                        } label: {
                            Label("Check Mirrors", systemImage: "antenna.radiowaves.left.and.right")
                        }
                        .disabled(isCheckingMirrors)
                    }
                }

                Section {
                    Text("Sci-Hub mirrors may change frequently. Use \"Check Mirrors\" to test connectivity. Green = reachable, Red = down.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tabItem { Label("Sci-Hub", systemImage: "network") }

            // AI Tab
            Form {
                Section("Apple ML Features (always available)") {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Paper similarity & connections")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Keyword extraction & tag suggestions")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Quick extractive summaries")
                    }
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("PDF text extraction")
                    }
                    Text("These features use Apple's built-in NaturalLanguage and PDFKit frameworks. No setup required.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Ollama LLM (optional — enhanced AI)") {
                    HStack {
                        switch aiService.ollamaStatus {
                        case .available:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Ollama running")
                            if !aiService.ollamaModel.isEmpty {
                                Text("(\(aiService.ollamaModel))")
                                    .foregroundStyle(.secondary)
                            }
                        case .unavailable:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                            Text("Ollama not available")
                        case .downloading(let p):
                            ProgressView(value: p)
                                .frame(width: 100)
                            Text("Downloading...")
                        case .unknown:
                            ProgressView().controlSize(.small)
                            Text("Checking...")
                        }

                        Spacer()

                        Button {
                            Task { await aiService.checkOllama() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if aiService.ollamaStatus == .available {
                        Text("Deep AI summaries, structured analysis, and smart tag suggestions are enabled.")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Text("Ollama enables deep paper summarization, structured analysis, and smart tag suggestions.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if aiService.ollamaStatus != .available {
                    Section("One-Click Setup") {
                        if isInstallingOllama {
                            VStack(alignment: .leading, spacing: 8) {
                                ProgressView(value: ollamaInstallProgress) {
                                    Text("Downloading Ollama...")
                                        .font(.caption)
                                }
                                Text("\(Int(ollamaInstallProgress * 100))%")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        } else if isPullingModel {
                            VStack(alignment: .leading, spacing: 8) {
                                ProgressView(value: modelPullProgress) {
                                    Text("Pulling model: \(selectedModel)")
                                        .font(.caption)
                                }
                                Text("\(Int(modelPullProgress * 100))%")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Click below to automatically download and set up Ollama. No terminal or API keys needed.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Picker("Model", selection: $selectedModel) {
                                    ForEach(OllamaManager.recommendedModels, id: \.name) { model in
                                        Text("\(model.name) — \(model.description) (\(model.size))")
                                            .tag(model.name)
                                    }
                                }
                                .pickerStyle(.radioGroup)

                                HStack {
                                    Button {
                                        Task { await installOllama() }
                                    } label: {
                                        Label("Install Ollama & Download Model", systemImage: "sparkles")
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.regular)

                                    if OllamaManager.isInstalled {
                                        Button {
                                            OllamaManager.start()
                                            Task {
                                                try? await Task.sleep(nanoseconds: 3_000_000_000)
                                                await aiService.checkOllama()
                                            }
                                        } label: {
                                            Label("Start Ollama", systemImage: "play.fill")
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                            }
                        }

                        if let error = aiError {
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }

                if aiService.ollamaStatus == .available {
                    Section("Model Management") {
                        if !localModels.isEmpty {
                            ForEach(localModels, id: \.self) { model in
                                HStack {
                                    Image(systemName: "cpu")
                                        .foregroundStyle(.blue)
                                    Text(model)
                                        .font(.system(.body, design: .monospaced))
                                }
                            }
                        }

                        Button {
                            Task {
                                localModels = await OllamaManager.localModels()
                            }
                        } label: {
                            Label("Refresh Models", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        HStack {
                            Button {
                                OllamaManager.stop()
                                Task {
                                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                                    await aiService.checkOllama()
                                }
                            } label: {
                                Label("Stop Ollama", systemImage: "stop.fill")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button(role: .destructive) {
                                try? OllamaManager.uninstall()
                                Task { await aiService.checkOllama() }
                            } label: {
                                Label("Uninstall Ollama", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
            .tabItem { Label("AI", systemImage: "sparkles") }
            .onAppear {
                Task { localModels = await OllamaManager.localModels() }
            }
        }
        .frame(width: 600, height: 580)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            downloadFolder = url.path
        }
    }

    private func saveMirrors() {
        UserDefaults.standard.set(scihubMirrors, forKey: AppConstants.scihubMirrorsKey)
    }

    private func installOllama() async {
        aiError = nil
        isInstallingOllama = true
        ollamaInstallProgress = 0

        do {
            // Step 1: Download Ollama binary
            try await OllamaManager.install { progress in
                Task { @MainActor in ollamaInstallProgress = progress }
            }

            isInstallingOllama = false

            // Step 2: Start server
            OllamaManager.start()
            try await Task.sleep(nanoseconds: 3_000_000_000)

            // Step 3: Pull selected model
            isPullingModel = true
            modelPullProgress = 0

            try await OllamaManager.pullModel(selectedModel) { progress in
                Task { @MainActor in modelPullProgress = progress }
            }

            isPullingModel = false

            // Step 4: Verify
            await aiService.checkOllama()
            localModels = await OllamaManager.localModels()

        } catch {
            isInstallingOllama = false
            isPullingModel = false
            aiError = error.localizedDescription
        }
    }

    private func checkMirrors() async {
        isCheckingMirrors = true
        mirrorStatus = [:]

        // Mark all as checking
        for mirror in scihubMirrors {
            mirrorStatus[mirror] = .checking
        }

        await withTaskGroup(of: (String, Bool).self) { group in
            for mirror in scihubMirrors {
                group.addTask {
                    guard let url = URL(string: mirror) else { return (mirror, false) }
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = 8
                    request.setValue(
                        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
                        forHTTPHeaderField: "User-Agent"
                    )
                    do {
                        let (_, response) = try await URLSession.shared.data(for: request)
                        if let http = response as? HTTPURLResponse {
                            return (mirror, (200...399).contains(http.statusCode))
                        }
                        return (mirror, false)
                    } catch {
                        return (mirror, false)
                    }
                }
            }

            for await (mirror, isUp) in group {
                await MainActor.run {
                    mirrorStatus[mirror] = isUp ? .reachable : .unreachable
                }
            }
        }

        isCheckingMirrors = false
    }
}
