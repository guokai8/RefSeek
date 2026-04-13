# Changelog

## v1.1.0 (2025-04-13)

### New Features

- **Advanced Search Filters**: Abstract keyword, Open Access toggle, minimum citations
- **Impact Factor Display**: Bundled JCR database (130+ journals, 2023 data) with OpenAlex fallback
- **JCR Quartile Badges**: Color-coded Q1–Q4 quartile display in search results
- **Open Access Badges**: Visual indicator for freely available papers
- **New Sort Options**: Sort by impact factor (descending), author (A→Z), title (A→Z)
- **Additional PDF Providers**: Semantic Scholar, OpenAlex OA, and Europe PMC added before Sci-Hub
- **Provider Tracking**: See which source successfully provided each PDF download

### Improvements

- **Enrichment Pipeline**: Async post-search enrichment fetches IF, quartile, and OA status from OpenAlex
- **Journal IF Lookup**: Cached actor-based lookup with bundled JCR database as primary source
- **Centralized User-Agent**: All API calls use configurable contact email from `AppConstants`
- **Sidebar Stability**: Fixed NSTableView reentrant operation warning by caching category list

### Bug Fixes

- Fixed NSTableView reentrant operation warning caused by mutating sidebar category list during render
- Fixed potential crash when enrichment data mutated results array during SwiftUI List rendering
- Deferred sidebar selection changes to avoid reentrancy issues

---

## v1.0.0 (2025-04-09)

### Features

- **Multi-Engine Search**: PubMed, CrossRef, Semantic Scholar, OpenAlex — up to 200 results per query
- **Structured Queries**: `author:`, `title:`, `year:`, `journal:` syntax
- **Multi-Source PDF Download**: Unpaywall → PMC → Sci-Hub (with configurable mirrors)
- **Batch Download**: Select multiple results or download all at once
- **Sort Results**: By relevance, year (asc/desc), citation count, or journal name
- **Paper Library**: Tags, categories, notes, search/filter, BibTeX export
- **AI — Zero Setup** (Apple ML):
  - Similar paper detection via NLEmbedding
  - Quick extractive summaries
  - Keyword extraction & smart tag suggestions
  - PDF text extraction
- **AI — Enhanced** (Ollama, optional):
  - One-click Ollama install from within the app
  - Deep structured paper summaries
  - LLM-powered tag suggestions
- **Menu Bar**: Quick search from the menu bar
- **Global Hotkey**: ⌘⇧R to search selected text from any app
- **Right-Click Service**: "Search in RefSeek" from any app's Services menu
- **Universal Binary**: Runs natively on Intel and Apple Silicon Macs
