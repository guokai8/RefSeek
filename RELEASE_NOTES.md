# RefSeek v1.1.0

**A native macOS app for searching, downloading, and managing academic papers — with built-in AI.**

## Download

| File | Size | Description |
|------|------|-------------|
| `RefSeek-v1.1.0-macOS-universal.dmg` | 3.2 MB | Disk image (drag to Applications) |
| `RefSeek-v1.1.0-macOS-universal.zip` | 2.7 MB | Zip archive |

> **Requires macOS 14.0 (Sonoma) or later.** Universal binary — runs natively on both Intel and Apple Silicon Macs.
> 
> Since the app is unsigned, right-click → **Open** on first launch.

## What's New in v1.1.0

### Impact Factor & Journal Metrics
- **Bundled JCR Database**: 130+ major journals with 2023 JCR Impact Factors (Nature: 50.5, Cell: 45.5, Lancet: 98.4, NEJM: 96.2, etc.)
- **JCR Quartile Badges**: Color-coded Q1 (red), Q2 (orange), Q3 (yellow), Q4 (gray) for every result
- **OpenAlex Fallback**: Journals not in the bundled DB get estimated IF from OpenAlex (labeled "IF~")
- **Open Access Badges**: Instantly see which papers are freely available

### Enhanced Search
- **Advanced Filters**: Abstract keyword search, Open Access toggle, minimum citation count
- **New Sort Options**: Impact factor ↓, Author A→Z, Title A→Z (in addition to existing sorts)
- **Async Enrichment**: IF, quartile, and OA status are fetched in the background after search

### More PDF Sources
- **3 New Providers**: Semantic Scholar, OpenAlex OA, and Europe PMC — tried before Sci-Hub
- **Provider Tracking**: See which source successfully downloaded each paper
- Full download chain: Semantic Scholar → OpenAlex → Europe PMC → Unpaywall → PMC → Sci-Hub

### Bug Fixes
- Fixed NSTableView reentrant operation warning (sidebar crash)
- Fixed enrichment data mutation during SwiftUI List rendering

## All Features

### Search & Download
- Search across **PubMed**, **CrossRef**, **Semantic Scholar**, and **OpenAlex**
- Up to 200 results per query with impact factor, quartile, and OA badges
- Structured queries: `author:Smith title:CRISPR year:2024`
- Advanced filters: abstract, open access, minimum citations
- 6-source PDF download pipeline with batch support

### Paper Library
- Tags, categories, notes, search/filter
- BibTeX export and import
- PDF viewer integration

### AI Features (zero setup — works immediately)
- **Similar Papers**: Apple NLEmbedding-based similarity
- **Quick Summary**: Extractive key sentences
- **Tag Suggestions**: AI keyword extraction
- **PDF Text Extraction**: Reads downloaded PDFs

### AI Features (optional — Ollama)
- **One-Click Install**: Set up Ollama from within the app
- Deep structured summaries and LLM-powered tag suggestions

### Extras
- Menu bar quick access
- Global hotkey ⌘⇧R
- Right-click "Search in RefSeek" service

## SHA256 Checksums

```
9e9a8d183682b5c3dd3614d2ec46f5c7064283535ddeb62402bc9cb3d24c84fd  RefSeek-v1.1.0-macOS-universal.dmg
701c84764164682ad531d05b3ae3a8d46514bee7fef919da76038d69f079e639  RefSeek-v1.1.0-macOS-universal.zip
```
