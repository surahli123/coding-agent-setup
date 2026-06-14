# CLI Tools — Detailed Command Catalog

Lazy-loaded reference. Pointer lives in `~/CLAUDE.md` under "CLI Tools (Installed)".
Load this when you actually need opencli/autocli subcommand syntax.

## opencli / autocli — command reference

Both at `/opt/homebrew/bin/`, installed via npm (`@jackwener/opencli`). Turn 100+
websites into CLI adapters (Reddit, Twitter/X, Hackernews, Google, Yelp, Tripadvisor,
Bilibili, Amazon, LinkedIn, etc.). Daemon + Chrome browser-bridge extension must be
running (check `opencli doctor`).

- Discover: `opencli list` (full inventory) / `opencli reddit --help` (per-site subcommands)
- Recent-content filter ("last 30 days" / 上 N 天): `--time {hour|day|week|month|year|all}`
  (this is what the user refers to as "/last30days")
- Output format for LLM consumption: `-f md` or `-f yaml` (default `table` works too)
- Common useful commands for research:
  - `opencli reddit search "<query>" --subreddit <name> --time month --sort top --limit 15 -f md`
  - `opencli reddit read <post-id> -f md` (full post + comments)
  - `opencli google search "<query>" -f md`
  - `opencli twitter search "<query>" -f md`

## twitter CLI (detail)

Installed at `~/.local/bin/twitter` via `uv tool`.
- Read a long-form X Article: `twitter article -m <url>` — errors with `not_found: no article content` on plain tweets
- Read a plain tweet + replies: `twitter tweet <url>` (verified; `article` does NOT work for these)
- Search tweets: `twitter search "<query>"`
- Compact mode (LLM-friendly): `twitter -c <command>` — note: truncates long tweet text; drop `-c` when you need full text
