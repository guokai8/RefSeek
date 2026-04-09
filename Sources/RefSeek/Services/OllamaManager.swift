import Foundation

/// Manages a local Ollama installation entirely within RefSeek's app support directory.
/// Users never need to touch the terminal — just click "Enable AI".
enum OllamaManager {

    /// Where Ollama lives: ~/Library/Application Support/RefSeek/ollama/
    static var ollamaDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("RefSeek/ollama", isDirectory: true)
    }

    static var binaryPath: URL {
        ollamaDir.appendingPathComponent("ollama")
    }

    static var modelsDir: URL {
        ollamaDir.appendingPathComponent("models", isDirectory: true)
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: binaryPath.path)
    }

    /// Check if the Ollama server process is running
    static var isRunning: Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-f", binaryPath.path]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }

    // MARK: - Download Ollama Binary

    /// Download the Ollama binary for macOS.
    /// Progress callback receives 0.0–1.0.
    static func install(progress: @escaping (Double) -> Void) async throws {
        let fm = FileManager.default
        try fm.createDirectory(at: ollamaDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: modelsDir, withIntermediateDirectories: true)

        // Download Ollama CLI from GitHub releases
        let arch = ProcessInfo.processInfo.machineHardwareName
        let downloadURL: URL
        if arch == "arm64" {
            downloadURL = URL(string: "https://ollama.com/download/ollama-darwin-arm64")!
        } else {
            downloadURL = URL(string: "https://ollama.com/download/ollama-darwin-amd64")!
        }

        // Use URLSession with delegate for progress
        let (localURL, _) = try await downloadWithProgress(url: downloadURL, progress: progress)

        // Move to final location
        if fm.fileExists(atPath: binaryPath.path) {
            try fm.removeItem(at: binaryPath)
        }
        try fm.moveItem(at: localURL, to: binaryPath)

        // Make executable
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binaryPath.path)

        progress(1.0)
    }

    /// Uninstall Ollama and all models
    static func uninstall() throws {
        stop()
        if FileManager.default.fileExists(atPath: ollamaDir.path) {
            try FileManager.default.removeItem(at: ollamaDir)
        }
    }

    // MARK: - Server Management

    /// Start the Ollama server in the background
    static func start() {
        guard isInstalled, !isRunning else { return }

        let process = Process()
        process.executableURL = binaryPath
        process.arguments = ["serve"]
        process.environment = [
            "OLLAMA_MODELS": modelsDir.path,
            "HOME": FileManager.default.homeDirectoryForCurrentUser.path,
            "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
        ]
        // Suppress output
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try? process.run()
        // Don't waitUntilExit — it runs as a background server
    }

    /// Stop the Ollama server
    static func stop() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        task.arguments = ["-f", binaryPath.path]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
    }

    // MARK: - Model Management

    /// Pull a model. Progress callback gets 0.0–1.0.
    static func pullModel(_ model: String, progress: @escaping (Double) -> Void) async throws {
        guard isInstalled else {
            throw NSError(domain: "OllamaManager", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Ollama not installed"])
        }

        // Ensure server is running
        if !isRunning {
            start()
            try await Task.sleep(for: .seconds(3))
        }

        // Use the Ollama API to pull
        guard let url = URL(string: "http://localhost:11434/api/pull") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 600 // models can be large

        let body = ["name": model]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        // Stream the response for progress
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(domain: "OllamaManager", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to pull model"])
        }

        for try await line in bytes.lines {
            // Each line is a JSON object like {"status":"pulling ...","completed":123,"total":456}
            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let completed = json["completed"] as? Double,
                   let total = json["total"] as? Double, total > 0 {
                    await MainActor.run { progress(completed / total) }
                }
                if let status = json["status"] as? String, status == "success" {
                    await MainActor.run { progress(1.0) }
                }
            }
        }
    }

    /// List locally pulled models
    static func localModels() async -> [String] {
        guard isRunning || isInstalled else { return [] }
        return await OllamaHelper.availableModels()
    }

    // MARK: - Recommended Models

    struct ModelInfo {
        let name: String
        let description: String
        let size: String
    }

    static let recommendedModels: [ModelInfo] = [
        ModelInfo(name: "qwen2.5:1.5b", description: "Fast & small, good for summaries", size: "~1 GB"),
        ModelInfo(name: "llama3.2:3b", description: "Balanced quality & speed", size: "~2 GB"),
        ModelInfo(name: "llama3.2", description: "Best quality (default)", size: "~4 GB"),
        ModelInfo(name: "gemma2:2b", description: "Google's small model", size: "~1.6 GB"),
    ]

    // MARK: - Private

    private static func downloadWithProgress(url: URL, progress: @escaping (Double) -> Void) async throws -> (URL, URLResponse) {
        let delegate = DownloadProgressDelegate(progress: progress)
        let session = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let request = URLRequest(url: url)
        return try await session.download(for: request)
    }
}

// MARK: - Download Progress Delegate

private class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    let progressHandler: (Double) -> Void

    init(progress: @escaping (Double) -> Void) {
        self.progressHandler = progress
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let p = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            DispatchQueue.main.async { self.progressHandler(p) }
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // Handled by the async caller
    }
}

// MARK: - ProcessInfo Extension

extension ProcessInfo {
    var machineHardwareName: String {
        var sysinfo = utsname()
        uname(&sysinfo)
        return withUnsafePointer(to: &sysinfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}
