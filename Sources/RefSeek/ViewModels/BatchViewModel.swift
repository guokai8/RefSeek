import Foundation
import SwiftUI

@MainActor
class BatchViewModel: ObservableObject {
    @Published var batchItems: [BatchItem] = []
    @Published var isRunning = false

    private let fetcher = PaperFetcher()
    private var tasks: [Task<Void, Never>] = []

    func startBatch(items: [String], store: PaperStore) async {
        isRunning = true
        batchItems = items.map { BatchItem(query: $0) }
        tasks = []

        let maxConcurrent = UserDefaults.standard.integer(forKey: AppConstants.maxConcurrentDownloadsKey)
        let semaphore = AsyncSemaphore(limit: maxConcurrent > 0 ? maxConcurrent : AppConstants.defaultMaxConcurrentDownloads)

        await withTaskGroup(of: Void.self) { group in
            for item in batchItems {
                group.addTask { [weak self] in
                    await semaphore.wait()
                    defer { Task { await semaphore.signal() } }
                    await self?.processItem(item, store: store)
                }
            }
        }

        isRunning = false
    }

    func cancelAll() {
        tasks.forEach { $0.cancel() }
        isRunning = false
    }

    private func processItem(_ item: BatchItem, store: PaperStore) async {
        // Step 1: Resolve DOI if needed
        var doi = item.doi
        if doi == nil {
            await MainActor.run { item.status = .resolving }
            do {
                let results = try await DOIResolver.resolve(title: item.query, maxResults: 1)
                if let first = results.first {
                    doi = first.doi
                    await MainActor.run {
                        item.doi = first.doi
                        item.title = first.title
                    }
                } else {
                    await MainActor.run { item.status = .failed("DOI not found") }
                    return
                }
            } catch {
                await MainActor.run { item.status = .failed("Resolve failed") }
                return
            }
        }

        guard let resolvedDOI = doi else {
            await MainActor.run { item.status = .failed("No DOI") }
            return
        }

        // Step 2: Download
        await MainActor.run { item.status = .downloading(0) }
        do {
            _ = try await fetcher.fetchAndSave(
                doi: resolvedDOI,
                store: store,
                progressHandler: { progress in
                    Task { @MainActor in
                        item.status = .downloading(progress)
                    }
                }
            )
            await MainActor.run { item.status = .completed }
        } catch {
            await MainActor.run { item.status = .failed(error.localizedDescription) }
        }
    }
}

/// Simple async semaphore for limiting concurrency
actor AsyncSemaphore {
    private var count: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.count = limit
    }

    func wait() async {
        if count > 0 {
            count -= 1
        } else {
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }
    }

    func signal() {
        if waiters.isEmpty {
            count += 1
        } else {
            let next = waiters.removeFirst()
            next.resume()
        }
    }
}
