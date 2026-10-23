# Public source alpha gate

Accepted bounded source state: `39e06348f5063442f1dec288766d786e1268e547` from the development checkout. Twelve core tests passed; independent source/package review verified five local app/archive hashes, ad-hoc signatures and ZIP integrity. Import/export metadata roundtrip and failed-save rollback fixes are covered by tests.

Open: build and restore from this clean export; run the exact exported app packages; complete UI, accessibility, performance and four-variant behavior review; directly compare a lawful vidIQ reference before making any fidelity statement; and review future provider permissions before adding network adapters.

This source-only alpha is not a notarized app release or a completed faithful vidIQ recreation. The four custom variants share a JSON library and concurrent writers across app processes are not coordinated.
