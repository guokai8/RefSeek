# RefSeek

<p align="center">
  <img src="Sources/RefSeek/Resources/AppIcon_256.png" width="128" alt="RefSeek Icon"/>
</p>

<p align="center">
  <strong>A native macOS app for searching, downloading, and managing academic papers — with built-in AI.</strong>
</p>

<p align="center">
  <a href="https://github.com/guokai8/RefSeek/releases">Download</a> ·
  <a href="#features">Features</a> ·
  <a href="#installation">Installation</a> ·
  <a href="#build-from-source">Build from Source</a>
</p>

---

## Features

### Search & Download
- **Multi-Engine Search**: Search across **PubMed**, **CrossRef**, **Semantic Scholar**, and **OpenAlex** — up to 200 results per query
- **Smart Query Parsing**: Supports structured queries (`author:Smith title:CRISPR year:2024 journal:Nature`)
- **Advanced Search Filters**: Abstract keyword, Open Access toggle, minimum citations
- **Multi-Source PDF Download**: Semantic Scholar → OpenAlex → Europe PMC → Unpaywall → PMC → Sci-Hub
- **Batch Download**: Select multiple results and download with one click, or bulk download all
- **Sort Results**: By relevance, year, citation count, impact factor, journal, author, or title
- **Journal Impact Factor**: Bundled JCR database (130+ journals) with OpenAlex fallback
- **JCR Quartile Badges**: Color-coded Q1–Q4 quartile display for each result
- **Open Access Badges**: Instantly see which papers are freely available

### Paper Library
- **Organize**: Tags, categories, notes, and full-text search/filter
- **BibTeX Export**: Generate citations for individual papers or the entire library
- **PDF Viewer**: Open downloaded PDFs directly
- **BibTeX Import**: Paste or import BibTeX entries

### AI Features (built-in, no setup required)
- **Similar Papers**: Automatically finds related papers in your library using Apple NLEmbedding
- **Quick Summary**: Extracts key sentences from abstracts or PDFs instantly
- **Smart Tag Suggestions**: AI-powered keyword extraction and tag recommendations
- **PDF Text Extraction**: Reads text from downloaded PDFs for analysis

### AI Features (optional — Ollama)
- **One-Click Setup**: Install Ollama from within the app — no terminal, no API keys
- **Deep Summaries**: Structured analysis with Key Findings, Methods, Significance, Limitations
- **Smart Tag Suggestions**: LLM-aware suggestions that learn from your existing tags

### Extras
- **Menu Bar Quick Access**: Search from the menu bar without opening the full app
- **Global Hotkey**: Press ⌘⇧R to search selected text from any app
- **Right-Click Service**: Select text → right-click → "Search in RefSeek"

## Installation

### Download (recommended)

1. Download `RefSeek.dmg` from the [latest release](https://github.com/guokai8/RefSeek/releases)
2. Open the DMG and drag `RefSeek.app` to your Applications folder
3. Right-click the app → **Open** (required on first launch since the app is unsigned)

> **Requires macOS 14.0 (Sonoma) or later.** Universal binary — runs natively on both Intel and Apple Silicon Macs.

### Build from Source

```bash
git clone https://github.com/guokai8/RefSeek.git
cd RefSeek
swift build -c release
swift run RefSeek
```

Or open `Package.swift` in Xcode and press ⌘R.

To build a universal binary:
```bash
swift build -c release --arch x86_64 --arch arm64
```

## Data Storage

```
~/Library/Application Support/RefSeek/
├── papers.json        # Paper library
├── tags.json          # Tags
├── embeddings.json    # AI paper embeddings (auto-generated)
└── ollama/            # Managed Ollama installation (optional)
```

PDFs are saved to `~/Downloads/RefSeek/` by default (configurable in Settings).

## Configuration

Open **Settings** (⌘,) to configure:

| Tab | Options |
|-----|---------|
| **General** | Download folder, search engine, max results, concurrent downloads, global hotkey |
| **Sci-Hub** | Mirror URLs, health check, add/remove mirrors |
| **AI** | Apple ML status, one-click Ollama install, model management |

## Architecture

```
User Input (title, DOI, or structured query)
    ↓
Search Engine (PubMed / CrossRef / Semantic Scholar / OpenAlex)
    ↓
Results with metadata (title, authors, journal, year, citation count)
    ↓
Enrichment: Impact Factor (JCR DB + OpenAlex) · OA status · JCR Quartile
    ↓
PDF Download: Semantic Scholar → OpenAlex → Europe PMC → Unpaywall → PMC → Sci-Hub
    ↓
Paper Library (JSON persistence)
    ↓
AI Analysis: Embeddings → Similarity → Summaries → Tag Suggestions
```

## Project Structure

```
Sources/RefSeek/
├── RefSeekApp.swift              # App entry point
├── Models/                       # Paper, SearchResult, Tag, BatchItem
├── Views/
│   ├── Search/                   # Search interface & result rows
│   ├── Library/                  # Paper library & detail view
│   ├── Batch/                    # Batch import/download
│   ├── Settings/                 # Settings (General, Sci-Hub, AI)
│   └── MenuBar/                  # Menu bar popover
├── ViewModels/                   # SearchViewModel, BatchViewModel
├── Services/
│   ├── AIService.swift           # Unified AI (Apple ML + Ollama)
│   ├── EmbeddingStore.swift      # Paper embeddings persistence
│   ├── OllamaManager.swift       # One-click Ollama management
│   ├── OllamaHelper.swift        # Ollama API client
│   ├── PaperStore.swift          # JSON persistence layer
│   ├── PaperFetcher.swift        # PDF download orchestration
│   ├── JournalIFLookup.swift     # Impact factor lookup (JCR DB + OpenAlex)
│   ├── DOIResolver.swift         # CrossRef API / DOI resolution
│   ├── PubMedSearcher.swift      # PubMed E-utilities
│   ├── SemanticScholarSearcher.swift
│   ├── OpenAlexSearcher.swift
│   └── Providers/                # Semantic Scholar, OpenAlex, Europe PMC, Unpaywall, PMC, Sci-Hub
└── Utilities/                    # Constants, parsers, formatters
```

## Screenshots

> Coming soon

## Author

**Kai Guo**
- GitHub: [@guokai8](https://github.com/guokai8)
- Email: [guokai8@gmail.com](mailto:guokai8@gmail.com)

## License

MIT License — see [LICENSE](LICENSE) for details.

## Legal Note

RefSeek supports multiple paper sources. Unpaywall and PubMed Central provide legal open access to papers. Use of Sci-Hub may not be legal in all jurisdictions. Users are responsible for compliance with local laws.
