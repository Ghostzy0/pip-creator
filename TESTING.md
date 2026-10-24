# Test status

`swift test --jobs 2` passes 13 CreatorCore tests on macOS 27 with Swift 6.4. Coverage includes quoted/multiline CSV, typed JSON, size/schema/count validation, API provenance rejection across source aliases and conflicting labels, dedupe, unknown versus zero, formula-safe CSV, local persistence and recovery, workspace persistence, CSV/JSON ID and metadata roundtrip, selected-record filtering, and failed-write rollback.

Four local ad-hoc-signed app bundles were built for the Core/Plus × Neutral/Pip editions from the source corresponding to this change; local signatures and ZIP integrity were verified in the development workspace. The clean public clone must still be rebuilt and restored before relying on its package receipts. No current-source variant was launched; visual/accessibility/performance acceptance and clean-clone package verification remain open.
