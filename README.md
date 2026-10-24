# Pip Creator

A local macOS app for organizing creator video research, raw values, sources and personal notes. The four editions share one native SwiftUI app and one data engine: Neutral Core, Neutral Plus, Pip Core and Pip Plus. This is an independent project and is not affiliated with vidIQ.

## What works

The current offline alpha supports manual notes; user-selected UTF-8 CSV and JSON import; local search and persistence; source, capture date and raw views/likes/comments; local workspace collections in Plus; clearly labelled fictional sample records; and selected-record CSV/JSON export. Missing values stay distinct from zero. Imports preserve record IDs, notes, dates, workspace and sample provenance across roundtrips. Declared YouTube Data API or Analytics markers in either `source` or `provenance` are rejected by the manual import path, including contradictory labels.

No YouTube account, analytics, keyword-volume, competition-score, outlier-ranking, paid-data or AI-provider connection is included. Search scans the records you supply; it does not predict views or promise SEO gains. The independent documented-workflow baseline lives at [pip-creator-replica](https://github.com/Ghostzy0/pip-creator-replica); it is not a faithful visual or algorithmic recreation.

## Build and test

Requires macOS 14 or newer and Swift 6.4 or a compatible later toolchain.

```sh
swift test --jobs 2
swift build -c release --product PipCreator
scripts/package-macos.sh
```

The packaging script creates local ad-hoc-signed apps and ZIP archives with source and SHA-256 receipts. They are not notarized. No downloadable binary release is published.

## Editions

| App | Theme | Features |
|---|---|---|
| Creator Studio | Neutral | Core library |
| Creator Studio Plus | Neutral | Core plus workspace collections |
| Pip Creator | Pip | Same Core library |
| Pip Creator Plus | Pip | Same Plus workspace collections |

The two shared engine files are byte-for-byte aligned with the Neutral Core baseline; see [core source hashes](CORE-SOURCE.md).

## Use and import format

Add a note, import a UTF-8 CSV or JSON array, search your library, then review selected records before choosing a save location. CSV accepts `id`, `title`, `channel`, `url`, `published_at`, `captured_at`, `source`, `views`, `likes`, `comments`, `workspace`, and `notes`; JSON accepts an array of objects with the corresponding fields. Titles are required. For example: `title,channel,views` followed by `My video,My channel,` with no count supplied. Imports are capped at 25 MB; malformed counts are rejected. A missing metric is not treated as zero. CSV export prefixes formula-leading cells for spreadsheet safety. The app does not upload exports; the user chooses where to save them.

Core contains the local library and export flows. Plus adds named workspace collections. Neutral and Pip editions share behavior; Pip uses original product styling. The four custom app variants share `~/Library/Application Support/PipCreator/library.json`; run one variant at a time because cross-process writes are not coordinated.

## Privacy, recovery and support

The app makes no network requests and stores no provider credentials. Research stays in the local application-support folder unless you export it. If a saved library is unreadable, the app preserves the original before the next successful write. See [FAQ](FAQ.md), [data boundaries](PARITY.md), [test status](TESTING.md), [release receipts](RELEASES.md), [acceptance gates](FINAL-GATE.md), [shared engine hashes](CORE-SOURCE.md), and [discoverability policy](DISCOVERABILITY.md).

## Project status

This is an early source alpha. Source-level tests and local package integrity checks pass, but no native visual walkthrough or accessibility/performance review is claimed. API and model integrations, public binary distribution and a faithful vidIQ comparison are out of scope for this release.
