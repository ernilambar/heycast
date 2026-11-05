# Search

## Index

- `.app` bundles under `/Applications`, `/System/Applications` and
  `~/Applications`, including symlinked bundles such as Safari.
- Snippets from the snippets folder. See [snippets.md](snippets.md).
- The app scan runs in the background the first time the palette opens.
- Apps installed after Heycast starts appear on the next launch.

## Ranking

- Match tiers, best first: exact, prefix, acronym, word-prefix, substring,
  subsequence. Usage breaks ties inside a tier.
- Empty query: frequently and recently launched apps first, then the rest
  alphabetically.
- The panel grows from one to seven visible rows, then scrolls.

## Usage history

- Stored locally in
  `~/Library/Application Support/net.nilambar.heycast/usage.json`.
- Scores damp raw launch counts logarithmically and halve every 30 days without
  a launch.
- Capped at the 200 most recently used apps.
