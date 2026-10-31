# Global agent instructions

The global instructions in this file apply in every project. Project-specific
rules live in each repository's `AGENTS.md`.

## Working agreements

- Ask before destructive or hard-to-reverse actions: deleting files,
  force-pushing, rewriting git history, dropping data, or changing CI/CD and
  infrastructure.
- Don't commit or push unless I ask. Never commit secrets or `.env` files.
- Ask before sending anything to an external service.
- Prefer small, reviewable changes that match the surrounding code style.
- When you finish, say what changed and how you verified it. If tests fail or
  you skipped a step, say so plainly.

## Python

- Use `uv` for everything Python: `uv run`, `uv add`, `uv sync`, `uvx`.
- Never use `pip`, `pip install`, or a bare `python` for project work.

## Shell commands: RTK

Prefix every shell command with `rtk`: `rtk git status`, `rtk cargo test`,
`rtk npm run build`, `rtk ls src/`. Keep the prefix — RTK has no filter for
`rtk git add`, `rtk git commit -m "msg"`. Commands RTK has no mapping for run
as-is, so the prefix is always safe. If a hook already adds the prefix, it
leaves the rewritten command alone.

Command output here is condensed to save tokens while keeping every signal and
dropping mostly noise. Treat it as the complete result; run commands normally,
and batch related commands into one call to avoid extra turns. Truncated
results state their recovery path in their own output. Re-run a command as
`rtk proxy <cmd>` only when its result is unusually empty when you expected
content.

- `rtk gain` / `rtk gain --history`: token savings, overall and per command.
- `rtk proxy <cmd>`: run a command unfiltered, still tracked.
- `RTK_DISABLED=1 <cmd>`: skip RTK for one command.
