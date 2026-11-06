# Search

## Index

- `.app` bundles under `/Applications`, `/System/Applications` and
  `~/Applications`, including symlinked bundles such as Safari.
- Snippets from the snippets folder. See [snippets.md](snippets.md).
- Every palette open rescans the install roots in the background, so an app
  installed while Heycast runs appears on the next open. Opens that arrive
  during a scan collapse into one follow-up scan.
- Icons are cached per bundle, so a rescan does not re-render the list.

## Ranking

- Applications use name tiers, best first: exact, prefix, acronym,
  word-prefix, substring, subsequence. Usage breaks ties inside a tier.
- A snippet matches only when the query is exactly its keyword,
  case-sensitive. Its title is display-only; there is no fuzzy matching.
- Invalid snippet files appear after the results in the snippets scope, with
  the validation reason, and `⌘↩` reveals them in Finder.
- Empty query: frequently and recently launched apps first, then the rest
  alphabetically, then snippets by keyword, then invalid files by filename.
- The panel grows from one to seven visible rows, then scrolls.

## Usage history

- Stored locally in
  `~/Library/Application Support/net.nilambar.heycast/usage.json`.
- Scores damp raw launch counts logarithmically and halve every 30 days without
  a launch.
- Capped at the 200 most recently used apps.
