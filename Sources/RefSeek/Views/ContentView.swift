import SwiftUI

/// Sidebar navigation items. Category items use associated value.
enum SidebarItem: Hashable, Identifiable {
    case search
    case library
    case category(String)       // user-defined sub-library
    case uncategorized
    case batch

    var id: String {
        switch self {
        case .search: return "search"
        case .library: return "library"
        case .category(let name): return "cat:\(name)"
        case .uncategorized: return "uncategorized"
        case .batch: return "batch"
        }
    }

    var label: String {
        switch self {
        case .search: return "Search"
        case .library: return "All Papers"
        case .category(let name): return name
        case .uncategorized: return "Uncategorized"
        case .batch: return "Batch Download"
        }
    }

    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .library: return "books.vertical"
        case .category: return "folder"
        case .uncategorized: return "tray"
        case .batch: return "arrow.down.doc"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: PaperStore
    @State private var selectedItem: SidebarItem? = .search
    @State private var isAddingCategory = false
    @State private var newCategoryName = ""
    @State private var cachedCategories: [String] = []
    @State private var cachedUncategorizedCount: Int = 0

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Cat mascot header
                HStack(spacing: 6) {
                    CatMascot(size: 28, rounded: true)
                    Text("RefSeek")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 8)

                List(selection: $selectedItem) {
                    // Main sections
                    Section {
                        sidebarRow(.search, count: nil)
                        sidebarRow(.batch, count: nil)
                    }

                    // Library with sub-categories
                    Section("Library") {
                        sidebarRow(.library, count: store.papers.count)

                        ForEach(cachedCategories, id: \.self) { cat in
                            sidebarRow(.category(cat), count: store.papers(inCategory: cat).count)
                                .contextMenu {
                                    Button("Rename...") {
                                        renameCategory(cat)
                                    }
                                    Button("Delete Category", role: .destructive) {
                                        deleteCategory(cat)
                                    }
                                }
                        }

                        if cachedUncategorizedCount > 0 {
                            sidebarRow(.uncategorized, count: cachedUncategorizedCount)
                        }

                        // Add category button
                        if isAddingCategory {
                            HStack(spacing: 4) {
                                TextField("Category name", text: $newCategoryName)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.caption)
                                    .onSubmit { commitNewCategory() }
                                Button {
                                    commitNewCategory()
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                .buttonStyle(.plain)
                                Button {
                                    isAddingCategory = false
                                    newCategoryName = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        } else {
                            Button {
                                isAddingCategory = true
                            } label: {
                                Label("New Category", systemImage: "plus.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .listStyle(.sidebar)
                .onAppear { refreshCachedCategories() }
                .onChange(of: store.papers.count) { _ in refreshCachedCategories() }
                .onChange(of: store.knownCategories) { _ in refreshCachedCategories() }
            }
            .frame(minWidth: 180, idealWidth: 210, maxWidth: 280)

            switch selectedItem ?? .search {
            case .search:
                SearchView()
            case .library:
                LibraryView(categoryFilter: nil)
            case .category(let name):
                LibraryView(categoryFilter: name)
            case .uncategorized:
                LibraryView(categoryFilter: "")
            case .batch:
                BatchImportView()
            }
        }
        .frame(minWidth: 800, minHeight: 550)
        // Keyboard shortcuts: ⌘1/2/3 to switch tabs
        .keyboardShortcut("1", modifiers: .command, action: { selectedItem = .search })
        .keyboardShortcut("2", modifiers: .command, action: { selectedItem = .library })
        .keyboardShortcut("3", modifiers: .command, action: { selectedItem = .batch })
    }

    @ViewBuilder
    private func sidebarRow(_ item: SidebarItem, count: Int?) -> some View {
        HStack {
            Label(item.label, systemImage: item.icon)
            Spacer()
            if let count, count > 0 {
                Text("\(count)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .tag(item)
    }

    private func refreshCachedCategories() {
        cachedCategories = store.categories
        cachedUncategorizedCount = store.uncategorizedPapers.count
    }

    private func commitNewCategory() {
        let name = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        isAddingCategory = false
        newCategoryName = ""
        store.addCategory(name)
        refreshCachedCategories()
        DispatchQueue.main.async { selectedItem = .category(name) }
    }

    private func renameCategory(_ oldName: String) {
        // Use an alert-style approach (simplified: rename inline)
        let alert = NSAlert()
        alert.messageText = "Rename Category"
        alert.informativeText = "Enter a new name for \"\(oldName)\":"
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.stringValue = oldName
        alert.accessoryView = textField
        alert.addButton(withTitle: "Rename")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty && newName != oldName {
                store.renameCategory(oldName, to: newName)
                if case .category(oldName) = selectedItem {
                    selectedItem = .category(newName)
                }
            }
        }
    }

    private func deleteCategory(_ name: String) {
        store.deleteCategory(name)
        refreshCachedCategories()
        if case .category(name) = selectedItem {
            DispatchQueue.main.async { selectedItem = .library }
        }
    }
}

// Helper extension for keyboard shortcuts on any View
extension View {
    func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers, action: @escaping () -> Void) -> some View {
        self.background(
            Button("") { action() }
                .keyboardShortcut(key, modifiers: modifiers)
                .hidden()
        )
    }
}
