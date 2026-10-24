# Capabilities and evidence

Pip Creator is the improved custom offline app. It supports local notes, user-selected file import/export, search and workspace grouping in Plus. It does not connect YouTube or AI providers, generate titles/scripts, calculate search volume or competition, rank outliers, monitor competitor channels or provide performance predictions.

The companion `pip-creator-replica` project uses public Help Center documentation to organize its navigation. It has not been directly compared with a signed-in vidIQ UI. Neither app claims vidIQ affiliation or proprietary algorithm parity.

Import provenance labels record the supplied source; records with YouTube Data API or Analytics markers in either `source` or `provenance` are rejected by the manual import path even when another field says manual. CSV/JSON export supports selected records and preserves local ID, date, note, workspace and sample metadata. Only raw counts in user-selected source files are displayed. Missing values remain unknown, not zero.
