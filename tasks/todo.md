# RefSeek — Task Plan

## Overview
Native macOS SwiftUI app to download academic papers via title or DOI.
Features: single/batch download, BibTeX export, paper library, menubar quick access.

## Architecture
- **UI**: SwiftUI (macOS 14+), MVVM, sidebar navigation
- **Networking**: URLSession + async/await
- **Storage**: JSON file persistence (Codable), UserDefaults (settings)
- **Scraping**: Custom HTML parsing for Sci-Hub
- **Menubar**: MenuBarExtra API (macOS 13+)

## Tasks

### Phase 1: Project Skeleton & Models
- [x] Package.swift + project structure
- [x] RefSeekApp.swift (main window + menubar)
- [x] Models: Paper, Tag (Codable + JSON)
- [x] Utilities: DOIParser, Constants

### Phase 2: Services — DOI Resolution & Providers
- [x] DOIResolver (CrossRef API: title → DOI + metadata)
- [x] PaperProvider protocol
- [x] UnpaywallProvider (legal open access)
- [x] ScihubProvider (mirror rotation + HTML scraping)
- [x] PMCProvider (PubMed Central)
- [x] PaperFetcher orchestrator (try providers in order)
- [x] PDFValidator (magic bytes)
- [x] PaperStore (JSON persistence, CRUD, search)
- [x] AsyncSemaphore for concurrent download limiting

### Phase 3: Core UI — Search & Download
- [x] ContentView (sidebar: Search, Library, Batch)
- [x] SearchView + SearchViewModel (single paper search)
- [x] Search result rows with download button
- [x] Download progress indicator
- [x] Error handling & error banner

### Phase 4: Paper Library
- [x] LibraryView (list of downloaded papers with HSplitView)
- [x] PaperDetailView (metadata, notes, tags, open PDF)
- [x] Tag management (create, assign, remove, FlowLayout)
- [x] Library search & filtering
- [x] Context menus (open PDF, reveal in Finder, copy DOI/citation/BibTeX, delete)

### Phase 5: Batch Download
- [x] BatchImportView (paste DOIs/titles or import .txt/.csv)
- [x] BatchProgressView (queue with individual progress)
- [x] BatchViewModel
- [x] Concurrent download with AsyncSemaphore rate limiting

### Phase 6: BibTeX & Citation Export
- [x] BibTeXFormatter (Paper → BibTeX string)
- [x] Export single paper citation (copy to clipboard)
- [x] Export full library as .bib file (ExportBibTeXSheet)
- [x] Copy citation to clipboard

### Phase 7: Menubar Quick Access
- [x] MenuBarExtra with window style
- [x] Quick search field (auto DOI detect)
- [x] Recent downloads list (last 5)
- [x] Quick actions (open library, quit)

### Phase 8: Settings & Polish
- [x] SettingsView (download folder, Unpaywall email, Sci-Hub mirrors)
- [x] Sci-Hub mirror management (add/remove/reset)
- [x] Max concurrent downloads setting
- [ ] Proxy/network settings (deferred)
- [ ] Auto-update Sci-Hub mirrors (deferred)
- [ ] App icon (deferred)

### Phase 9: Verification
- [x] Build passes (swift build — clean)
- [x] App launches successfully
- [x] Fixed UTType crash in ExportBibTeXSheet
- [x] Fixed notes persistence (onChange save)
- [ ] Test DOI resolution with known titles (needs manual testing)
- [ ] Test each provider independently (needs manual testing)
- [ ] Test full flow end-to-end (needs manual testing)

## Review
- **Build**: ✅ Compiles cleanly with `swift build`
- **Launch**: ✅ App runs with `swift run RefSeek`
- **Architecture change**: Switched from SwiftData to JSON persistence (no Xcode available)
- **Files**: 21 Swift source files, well-organized MVVM structure
- **Remaining**: Manual testing of search/download, proxy settings, app icon
