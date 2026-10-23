# Test status

`swift test --jobs 2` passes 12 CreatorCore tests on macOS 27 with Swift 6.4. Coverage includes quoted/multiline CSV, typed JSON, size/schema/count validation, API provenance rejection, dedupe, unknown versus zero, formula-safe CSV, local persistence and recovery, workspace persistence, CSV/JSON metadata roundtrip, and failed-write rollback.

Four local ad-hoc-signed app bundles were built for the Core/Plus × Neutral/Pip editions. An independent source/package review verified their app and archive hashes, signatures and ZIP integrity. No exact package was launched, no visual/accessibility/performance walkthrough was completed, and no clean-clone public export build has yet been accepted.
