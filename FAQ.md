# Pip Creator FAQ

### Does Pip Creator connect to YouTube or an AI model?
No. The current app is offline. It makes no network requests and has no OAuth or provider-key UI.

### Does local search estimate keyword demand or views?
No. Search matches your saved titles, channels and notes. It does not calculate search volume, competition, proprietary scores or predictions.

### Can I import an official YouTube API export?
The manual-file path rejects records that declare YouTube Data API or Analytics provenance in either source field, including conflicting labels. A user-selected file or API key is not authorization for restricted derived metrics.

### What file formats are supported?
UTF-8 CSV and JSON arrays, with a required title and optional metadata, raw integer counts, notes and workspace. Selected-record export is also available in both formats. Imports are capped at 25 MB. See the README for the field names and details.

### Where is the library stored?
At `~/Library/Application Support/PipCreator/library.json`. All four variants share this file. Run one variant at a time because concurrent cross-process writes are not coordinated.

### Are there public binaries?
No. Local apps are ad-hoc signed and not notarized. The repository provides source and a packaging script; it does not claim general distribution readiness.
