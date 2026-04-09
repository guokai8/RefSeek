import SwiftUI

enum SidebarItem: String, CaseIterable, Identifiable {
    case search = "Search"
    case library = "Library"
    case batch = "Batch Download"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .library: return "books.vertical"
        case .batch: return "arrow.down.doc"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject private var store: PaperStore
    @State private var selectedItem: SidebarItem? = .search

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                // Cat mascot header
                HStack(spacing: 6) {
                    CatMascot(size: 28, rounded: true)
                    Text("RefSeek")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 8)

                List(SidebarItem.allCases, selection: $selectedItem) { item in
                    HStack {
                        Label(item.rawValue, systemImage: item.icon)
                        Spacer()
                        if item == .library && !store.papers.isEmpty {
                            Text("\(store.papers.count)")
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
                .listStyle(.sidebar)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 190)
        } detail: {
            switch selectedItem ?? .search {
            case .search:
                SearchView()
            case .library:
                LibraryView()
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
