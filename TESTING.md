# Test status

`swift test --jobs 2` passes 13 CreatorCore tests on macOS 27 with Swift 6.4. Coverage includes quoted/multiline CSV, typed JSON, size/schema/count validation, API provenance rejection across source aliases and conflicting labels, dedupe, unknown versus zero, formula-safe CSV, local persistence and recovery, workspace persistence, CSV/JSON ID and metadata roundtrip, selected-record filtering, and failed-write rollback.

For public candidate commit `0af08e617d86082718bf7abbb6e54f7d14060673`, four local ad-hoc-signed bundles were built for Core/Plus × Neutral/Pip. Strict code-signature verification and ZIP integrity checks passed for all four. This is local candidate-build evidence; a fresh clone from GitHub has not yet been restored and rebuilt. No current-source variant has completed a native walkthrough, and visual/accessibility/performance acceptance remains open.
