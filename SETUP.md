# Universal AI Coding Agent Setup

A tool-neutral, "define it once" setup for AI coding agents: Claude Code, Devin (CLI and Desktop), Codex CLI, Gemini CLI, Cursor, Copilot CLI and any future agent. It covers:

- **Global rules**: your personal instructions, written once and seen by every agent.
- **Project rules**: one `AGENTS.md` per repo, read by every agent.
- **Skills**: one folder of `SKILL.md` skills, shared by every agent.
- **Superpowers**: its skills copied once into the shared skills folder. No plugin and no session-start hook; you ask for a skill by name.
- **RTK**: token-saving shell output, through a hook where the agent supports one and a prompt rule everywhere.
- **MCP servers**: one source file, synced into every agent's own MCP config. Secrets never appear in any config file.

Out of scope: subagents, and org-managed items such as Claude's synced skills and remote settings. Those arrive automatically after login. See [section 12](#12-deliberately-not-covered).

> Written 2026-10-30. Checked against Claude Code 2.1.314, Devin CLI 3000.5.20 and RTK 0.52.0 on macOS.
> Statements marked **(verify)** come from docs or third-party sources that could not be confirmed on a real install.
> Check them the first time you follow this guide, and fix this file if they turn out wrong.

## Using this guide with an AI agent

You can hand this file to any coding agent:

> “Follow `SETUP.md` to set up AI agents on this machine.”

It assumes a **clean machine** (section 2.1).

Rules for the agent:

- Work through the sections in order.
- Run the clean-machine check in section 2.1 first. If it finds leftovers, list
  them and ask the human before removing anything.
- This is for **first-time setup**. If `~/.agents` already exists, agents are
  working, and you are adding another one, follow section 11.1 instead. Never
  re-create hub files in that case.
- Create hub files from the templates in section 16. If
  `~/.agents/AGENTS.md` does not exist, create it from 16.1 (section 3.2).
- Never overwrite an existing file without first backing it up to
  `/private/tmp/ai-setup-backup-<timestamp>/`. `link.sh` and `mcp-sync.sh`
  already do this.
- Run every `--dry-run` first, and show its output.
- Committing to the hub repo (sections 3.3, 4.2, 6.3) is part of this task.
  Ask the human before installing/removing a plugin, logging in, entering
  secrets, or pushing to a remote.
- Some commands ask a question (for example Gemini's `rtk init` in section 7).
  If you cannot answer prompts, ask the human to run them.
- Finish with the checklist in section 10. Report what passed, what failed,
  and what was skipped.

---

## Contents

0. [Concepts: how the pieces fit](#0-concepts-how-the-pieces-fit)
1. [Quick start (TL;DR)](#1-quick-start-tldr)
2. [Prerequisites](#2-prerequisites)
3. [Create the hub `~/.agents`](#3-create-the-hub-agents)
4. [Add skills to the hub](#4-add-skills-to-the-hub)
5. [Wire each agent](#5-wire-each-agent)
6. [Superpowers in every agent](#6-superpowers-in-every-agent)
7. [RTK in every agent](#7-rtk-in-every-agent)
8. [MCP servers in every agent](#8-mcp-servers-in-every-agent)
9. [Project-level setup (per repo)](#9-project-level-setup-per-repo)
10. [Verification checklist](#10-verification-checklist)
11. [Adding a new agent later](#11-adding-a-new-agent-later)
12. [Deliberately not covered](#12-deliberately-not-covered)
13. [Maintenance](#13-maintenance)
14. [Troubleshooting](#14-troubleshooting)
15. [Reference: support matrix and sources](#15-reference-support-matrix-and-sources)
16. [Appendix: file templates](#16-appendix-file-templates)

---

# 0. Concepts: how the pieces fit

### Two layers of instructions

| Layer | What goes in it | Where it lives | Who reads it |
|---|---|---|---|
| **Global rules** | Personal preferences that apply in every repo, e.g. “use uv”, “prefix shell commands with rtk”, “ask before force-pushing” | `~/.agents/AGENTS.md` | Every agent, each through its own expected location |
| **Project rules** | Facts about one repo: architecture, build/test commands, conventions | `<repo>/AGENTS.md`, committed with the code | Every agent, natively or through its expected location |

In a project, an agent loads both: global first, then project. A nested
`AGENTS.md` in a subfolder adds to them, and the closest file wins.

### Why global rules need "wiring"

There is a standard name for project rules (`AGENTS.md` at the repo root), but
**no standard location for global rules**. Each agent looks in its own place.
So keep one real file and make each agent's expected location lead to it.

| Agent | Looks for global rules at | How it reaches `~/.agents/AGENTS.md` |
|---|---|---|
| Claude Code | `~/.claude/CLAUDE.md` | A small `CLAUDE.md` containing `@~/.agents/AGENTS.md`. Claude expands `@` imports. A symlink is not used because Claude's Edit/Write tools refuse to write through symlinks, and desktop Cowork mode ignores a symlinked `~/.claude/CLAUDE.md`. |
| Devin CLI / Devin Desktop | `~/.config/devin/AGENTS.md` | symlink |
| Codex CLI | `~/.codex/AGENTS.md` | symlink |
| Gemini CLI | `~/.gemini/GEMINI.md` by default | setting so Gemini also reads files named `AGENTS.md`, plus symlink `~/.gemini/AGENTS.md` |
| Copilot CLI | `~/.copilot/copilot-instructions.md` | symlink |
| Cursor | Settings UI only | paste the content once (the one manual copy) |

Edit `~/.agents/AGENTS.md` once and every agent sees the change.

### Skills

Skills follow the **Agent Skills** open standard: a folder containing
`SKILL.md` with `name` and `description` frontmatter, plus optional
`scripts/`, `references/`, and `assets/`.

- `~/.agents/skills/<name>` is the emerging shared location. Devin CLI,
  Devin Desktop and Codex read it natively.
- Claude Code does **not** read it directly. `link.sh` creates
  `~/.claude/skills/<name>/` as a symlink to each skill there.
- Skills that only work in one agent stay in that agent's own folder.

### Superpowers: shared skills, no plugin

Superpowers is distributed as a plugin plus a session-start hook that injects
`using-superpowers` into every session. Without it, Superpowers is just a set
of skills, which is enough here.

You ask for skills yourself, so you do not need the hook.
`bin/superpowers-update.sh` copies the skills into the shared folder like any
other skill. You get one copy for every agent, one version, and nothing to
download on a machine that clones your hub.

### RTK: two mechanisms

1. **Hook (best):** the agent's shell-command hook rewrites `git status` to
   `rtk git status` automatically. Supported for Claude Code, Codex, Gemini,
   Cursor, Copilot, OpenCode, legacy Windsurf Cascade, and others.
2. **Prompt rule (fallback, universal):** the RTK section in
   `~/.agents/AGENTS.md` tells every agent to prefix commands with `rtk`.

Both together are safe.

### MCP: one source, synced, no secrets in configs

Each agent keeps its own MCP config location and format, for example:

- Claude: `~/.claude.json`
- Devin: `~/.config/devin/mcp_config.json`
- Codex: `~/.codex/config.toml`
- Gemini: `~/.gemini/settings.json`
- Cursor: `~/.cursor/mcp.json`
- Copilot: `~/.copilot/mcp-config.json`

Use one source:

```text
~/.agents/mcp/servers.json
```

Then:

1. `mcp-sync.sh` translates that common `mcpServers` shape.
2. Secrets live in one private file:
   `~/.config/agents/secrets.env`.
3. Every local server starts through `~/.config/agents/mcp/bin/with-secrets`,
   which loads the env file and then execs the real command.
4. Remote services that support OAuth should use OAuth instead of a static
   token in config.

---

### Final layout on a configured laptop

```text
~/.agents/                              <- THE HUB (your git repo, the single source of truth)
├── AGENTS.md                           global rules (all agents)
├── skills/<name>/SKILL.md              universal skills (all agents): yours + Superpowers'
├── mcp/
│   ├── servers.json                    MCP servers: single source (no secrets)
│   ├── bin/with-secrets                wrapper: loads secrets, then starts the server
│   └── servers/<name>/                 your own MCP server code (optional)
├── bin/link.sh                         idempotent wiring script (rules + skills)
├── bin/mcp-sync.sh                     idempotent MCP sync script
├── bin/superpowers-update.sh           copies Superpowers' skills into skills/
├── third_party/superpowers/            VERSION, skills.txt (which skills are Superpowers'), LICENSE
├── templates/AGENTS.project.md         starter for new repos
├── templates/secrets.env.example       list of secret names (no values)
└── SETUP.md                            this guide

~/.config/agents/secrets.env            PRIVATE: MCP secrets (chmod 600, never in git)
~/.config/agents/mcp-managed.txt        state: which servers mcp-sync.sh manages

~/.claude/CLAUDE.md                     real file: @~/.agents/AGENTS.md
~/.claude/skills/<name>                 -> symlink to ~/.agents/skills/<name>
~/.config/devin/AGENTS.md               -> symlink to ~/.agents/AGENTS.md
~/.codex/AGENTS.md                      -> symlink to ~/.agents/AGENTS.md
~/.gemini/AGENTS.md                     -> symlink to ~/.agents/AGENTS.md  (+ context.fileName setting)
~/.copilot/copilot-instructions.md      -> symlink to ~/.agents/AGENTS.md
```

---

# 1. Quick start (TL;DR)

```bash
# 1. prerequisites (agents already installed, started once, logged in) -> section 2
brew install git rtk uv node && rtk gain

# 2. then check the machine is clean (no leftover plugins/skills/rules/MCP) -> 2.1

# 3. clone your existing one, or build it from this guide -> section 3
git clone <your-private-hub-repo> ~/.agents
# or build ~/.agents by hand from sections 3.2 onward

# 4. skills, only when building the hub -> section 4
~/.agents/bin/superpowers-update.sh <superpowers-dir>

# 5. wire every installed agent -> section 5
~/.agents/bin/link.sh

# 6. Superpowers: nothing to install; ask for skills by name -> section 6

# 7. RTK hooks per agent -> section 7
# 8. MCP sync -> section 8
~/.agents/bin/mcp-sync.sh --dry-run
~/.agents/bin/mcp-sync.sh

# 9. run the checklist -> section 10
```

---

# 2. Prerequisites

```bash
# Homebrew (skip if present): https://brew.sh
brew install git rtk
# Runtimes most MCP servers need: uv/uvx (Python servers) and node/npx (Node servers)
brew install uv node      # or Node via nvm; the with-secrets wrapper finds nvm's latest Node
```

Check RTK is the **right** binary. A different crates.io package is also called
`rtk`, so do not `cargo install rtk`.

```bash
which rtk        # expect /opt/homebrew/bin/rtk
rtk --version    # expect "rtk 0.52.0" or newer
rtk gain         # must print the token-savings dashboard (empty is fine on a fresh machine)
```

The agents you use must already be installed — done manually, outside this
guide — and started/logged in once so they create their config folders.

Org-managed items, such as Claude's synced skills and remote policy settings,
appear automatically after login. Never copy them between machines.

## 2.1 Start from a clean machine

**First-time setup only.** To add an agent to a working setup, skip to 11.1.
Anything that points into `~/.agents` is part of your setup, not a leftover.

Check:

```bash
ls ~/.agents 2>/dev/null
ls -d ~/.claude/skills ~/.config/devin/skills ~/.codex/skills ~/.gemini/skills ~/.copilot/skills ~/.cursor/skills 2>/dev/null
ls -l ~/.claude/CLAUDE.md ~/.config/devin/AGENTS.md ~/.codex/AGENTS.md \
      ~/.gemini/AGENTS.md ~/.copilot/copilot-instructions.md 2>/dev/null
jq '{hooks,mcpServers}' ~/.claude/settings.json 2>/dev/null
jq '.mcpServers' ~/.cursor/mcp.json 2>/dev/null
```

What “clean” means:

| Item | Clean state |
|---|---|
| `~/.agents` | does not exist |
| Superpowers plugin | not installed in any agent, and no `superpowers_*` entry in Claude's `enabledPlugins`; check each agent's plugin list |
| Skill folders | empty apart from org-managed ones such as `~/.claude/skills/synced/` |
| Global rule files | none |
| Hooks | none |
| MCP servers | none apart from org-managed ones in any agent's MCP list/config |

Save any skill you want to keep (section 4.1), then remove the rest. That
includes hand-copied `superpowers-skills.sh`, MCP servers, and stale plugin
entries.

Back up everything you remove, e.g. to:

```text
/private/tmp/ai-setup-backup-<timestamp>/
```

---

# 3. Create the hub `~/.agents`

## 3.1 If you already have a hub in git

```bash
git clone https://rbcgithub.fg.rbc.com/<you>/agents-hub.git ~/.agents
chmod +x ~/.agents/bin/*.sh ~/.agents/mcp/bin/*
git -C ~/.agents status
```

It already contains your rules, skills (including Superpowers), and scripts.
Go to section 5.

## 3.2 Otherwise, build it from this guide

Do this when you do not have a hub in git yet.

> Creating `~/.agents/skills` takes effect at once. Devin, Codex, Gemini and Copilot start reading it as soon as it exists.

```bash
mkdir -p ~/.agents/{skills,bin,templates,mcp/bin,mcp/servers}
cp <path-to>/SETUP.md ~/.agents/SETUP.md
```

Create each file from the templates in section 16:

| File | Template |
|---|---|
| `~/.agents/AGENTS.md` | 16.1 Global `AGENTS.md` |
| `~/.agents/bin/link.sh` | 16.2 `link.sh` |
| `~/.agents/templates/AGENTS.project.md` | 16.3 Project `AGENTS.md` |
| `~/.agents/.gitignore` | 16.4 `.gitignore` |
| `~/.agents/mcp/servers.json` | 16.5 `servers.json` |
| `~/.agents/mcp/bin/with-secrets` | 16.6 `with-secrets` |
| `~/.agents/templates/secrets.env.example` | 16.7 `secrets.env.example` |
| `~/.agents/bin/mcp-sync.sh` | 16.8 `mcp-sync.sh` |
| `~/.agents/bin/superpowers-update.sh` | 16.9 `superpowers-update.sh` |

About the global `AGENTS.md`: it **must contain the “Shell commands: RTK” section
from 16.1**, copied as-is. That section is how every agent learns to prefix
commands with `rtk`. Add your own rules around it.

```bash
chmod +x ~/.agents/bin/*.sh ~/.agents/mcp/bin/*
```

## 3.3 Version it

```bash
cd ~/.agents && git init && git add -A && git commit -m "AI agent hub: initial"
```

Optionally push it to a **private** repo so another machine only needs section
3.1.

```bash
# after creating an empty private repo in the RBC GitHub web UI:
git -C ~/.agents remote add origin https://rbcgithub.fg.rbc.com/<you>/agents-hub.git
git push -u origin main
```

Keeping the hub in git also means that if a tool overwrites a shared file,
`git -C ~/.agents diff` shows it immediately.

> Never put secrets, tokens, `.env` files, or anything private in the hub.

---

# 4. Add skills to the hub

## 4.1 Your own skills

Each skill you want in every agent goes in:

```text
~/.agents/skills/<name>/SKILL.md
```

To write a new one, follow the Agent Skills standard, or ask any agent to use
a writing-skills skill once Superpowers is installed.

You can also copy a skill you saved in section 2.1:

- Put skills under the hub.
- `link.sh` links them into Claude, while other agents read the hub directly.
- A real copy in an agent's own folder would show twice.

## 4.2 Superpowers' skills

`superpowers-update.sh` needs a folder containing Superpowers' `skills/`.
Any copy works: a git clone, an unzipped release, or an installed plugin folder.

```bash
rm -rf /tmp/superpowers
git clone --depth 1 https://github.com/obra/superpowers.git /tmp/superpowers

SP=/tmp/superpowers          # if GitHub is blocked: download the zip in a browser, unzip, and point SP at it
~/.agents/bin/superpowers-update.sh --dry-run "$SP"
~/.agents/bin/superpowers-update.sh "$SP"

git -C ~/.agents add -A && \
git -C ~/.agents commit -m "Add Superpowers $(cat ~/.agents/third_party/superpowers/VERSION)"
```

Do not use hand-copied `superpowers-*` folders as the source. They are usually
stale.

---

# 5. Wire each agent

## 5.1 Run the linker

```bash
~/.agents/bin/link.sh
```

The script is idempotent, so re-run it whenever you add a skill or install a
new agent.

What it does:

1. **Claude Code:** creates `~/.claude/CLAUDE.md` with
   `@~/.agents/AGENTS.md` if the file does not exist.
2. Other agents: symlinks their global rules location to
   `~/.agents/AGENTS.md`.
3. `~/.claude/skills/<every ~/.agents/skills/<name>>` points at every shared
   skill folder in the hub; old links are removed.
4. Backs up existing real files before replacing them.
5. On macOS, clears `/private/tmp` on reboot. Keep backups permanently if needed.
6. Prints a warning if something is not what it expected.

## 5.2 Per-agent notes

### Claude Code

To add Claude-only notes, edit `~/.claude/CLAUDE.md` **below** the import line.
Never edit the import away.

Claude Code 2.1.277 or later also reads a project's `AGENTS.md` natively when
the project has no `CLAUDE.md`.

### Devin CLI and Devin Desktop

Devin Desktop (formerly Windsurf) and Devin CLI share
`~/.config/devin/`.

`~/.config/devin/skills` can point at the shared skill location.

Devin may also read project `CLAUDE.md`, but the hub is wired through the
native/current config. Avoid duplicate copies.

### Gemini CLI

It also needs a setting in its user config so `AGENTS.md` is recognized as a
context filename. Keep that setting if already configured.

### Cursor

User rules live only in:

```text
Cursor Settings -> Rules -> User Rules
```

Paste the contents of `~/.agents/AGENTS.md` there. This is the one place where
you must re-paste after changing the global rules. Project `AGENTS.md` works
natively.

### Codex and Copilot CLI

Nothing beyond the linker and the RTK setup in section 7.

---

# 6. Superpowers in every agent

Approach: Superpowers' skills live in `~/.agents/skills/` like your own skills.
No agent gets the plugin, so there is no session-start hook.

What you keep:

- all skills, in every agent,
- one version.

What you give up:

- the automatic “check for skills before every reply” at session start.

Agents may still pick a skill on their own when its description clearly fits
the task. Do not rely on that; ask for the skill by name when you want it.

## 6.1 Installing nothing to do

Section 4.2 put the skills in the hub.
`link.sh` makes them available to Claude; the other supported agents see them
through their shared/native skill folders.

Do **not** install the Superpowers plugin later, or you will get a second copy
of each skill and the session-start hook will return.

## 6.2 Using it

- **Claude Code:** `/brainstorming`, `/writing-plans`, `/systematic-debugging`, and so on. There's no `superpowers:` prefix any more, because these are plain user skills. Or just say **"use the brainstorming skill"**.
- **Other agents:** ask by name, e.g. **"Use the brainstorming skill: I want to build a small todo CLI"**.
- **Skill-to-skill references:** the skills mention each other as `superpowers:<name>`, e.g. `superpowers:writing-plans`. The skill is now just `writing-plans`, and agents usually make the connection. If one says it can't find `superpowers:*`, tell it **"use the x skill"**.
- `using-superpowers` is kept. It's the overview the hook used to inject, so **"use superpowers"** makes the agent load it and pick the right skill. Its description tells agents to use it in every conversation. If an agent starts loading it on its own at every session start and you don't want that, leave it out:
  `SUPERPOWERS_SKIP=using-superpowers ~/.agents/bin/superpowers-update.sh <superpowers-dir>`

Superpowers skills can reference each other; keep the full skill set together
under `~/.agents/skills`.

Common skills visible in this setup include:

| Ask for | When |
|---|---|
| `brainstorming` | before building anything; design and questions first, code later |
| `writing-plans` | turn a design spec into a step-by-step plan |
| `executing-plans` | carry out a plan |
| `subagent-driven-development` | carry out a plan by handing tasks to subagents |
| `test-driven-development` | write the failing test first, then code |
| `systematic-debugging` | debug or fix a failing test |
| `verification-before-completion` | before saying “done”; run checks and show output |
| `requesting-code-review` | receive/prepare code review |
| `using-git-worktrees` | start isolated feature work |
| `finishing-a-development-branch` | decide how to merge or close finished work |
| `writing-skills` | create or edit a skill |
| `diagnosing-superpowers` | analyze a skill / Superpowers session problem |
| `using-superpowers` | overview: how to find and use the skills above |

## 6.3 Updating

1. Get a newer copy of Superpowers:

```bash
rm -rf /tmp/superpowers
git clone --depth 1 https://github.com/obra/superpowers.git /tmp/superpowers
```

2. Preview, then apply:

```bash
SP=/tmp/superpowers          # if GitHub is blocked: download the zip in a browser, unzip, and point SP at it
~/.agents/bin/superpowers-update.sh --dry-run "$SP"
~/.agents/bin/superpowers-update.sh "$SP"
```

3. Review and commit:

```bash
git -C ~/.agents diff --stat
git -C ~/.agents add -A
git -C ~/.agents commit -m "Superpowers $(cat ~/.agents/third_party/superpowers/VERSION)"
```

`superpowers-update.sh`:

- copies each `skills/<name>/` folder into `~/.agents/skills/<name>/`;
- records the package version in `third_party/superpowers/skills.txt`;
- copies `VERSION` and `LICENSE` next to it;
- never replaces or removes a hub skill unless it is recorded as a Superpowers
  skill;
- skips a destination if it already exists as a different non-Superpowers skill
  and prints `conflict`;
- removes Superpowers skills that were dropped upstream;
- re-runs with the same source without changing anything.

---

## 7. RTK in every agent

### Rule of thumb

- **Always run `rtk init … --dry-run` first** to see exactly what it will write. Nothing is written in dry-run.
- **Never let `rtk init` write into a file that is a symlink to the hub.** It would edit your shared `~/.agents/AGENTS.md`.
- Where `rtk init` insists on writing instructions, create only its **hook file by hand**, using the content `--dry-run` prints.
- The RTK instructions live in the "Shell commands: RTK" section of `~/.agents/AGENTS.md` (required, section 3.2). Check it's there before this step.

```bash
rtk init --help          # current list of supported agents and flags
```

| Agent | Command | What it writes (RTK 0.52.0, from `--dry-run`) |
|---|---|---|
| Claude Code | `rtk init -g --hook-only` | PreToolUse hook `rtk hook claude` (matcher `Bash`) in `~/.claude/settings.json`. `--hook-only` skips RTK.md because the hub already has the text. |
| Gemini CLI | `rtk init -g --gemini --hook-only` | `~/.gemini/hooks/rtk-hook-gemini.sh` and a `BeforeTool` hook (matcher `run_shell_command`) in `~/.gemini/settings.json`. It asks before patching; answer yes, so run it in a terminal yourself. **Then** add the `AGENTS.md` setting (below). |
| Cursor | `rtk init -g --agent cursor` | `~/.cursor/hooks.json` (`PreToolUse`, matcher `Shell`, `rtk hook cursor`) |
| Codex CLI | **hand-made hook**, see below | `--codex` can't be combined with `--hook-only`. It would add `@~/.codex/RTK.md` to `~/.codex/AGENTS.md`, which is our symlink to the hub. |
| Copilot CLI | **hand-made hook**, see below | `--copilot` always appends to `~/.copilot/copilot-instructions.md`, which is our symlink to the hub. |
| Devin CLI and Desktop | none (no `rtk init` target) | Uses the prompt rule in `~/.agents/AGENTS.md`. Optional experimental hook below. |
| Legacy Windsurf Cascade | `rtk init -g --agent windsurf` | only if you still use legacy Cascade |
| OpenCode | `rtk init -g --opencode` | OpenCode plugin |

### Gemini: read `AGENTS.md`

Run this **after** Gemini's `rtk init`, which patches the same file:

```bash
f=~/.gemini/settings.json; [ -f "$f" ] || echo '{}' > "$f"
tmp=$(mktemp) && jq '.context.fileName = ["AGENTS.md","GEMINI.md"]' "$f" > "$tmp" && mv "$tmp" "$f"
```

This makes Gemini read `~/.gemini/AGENTS.md` (the hub link) and every project's `AGENTS.md`. Check with `/memory show` in Gemini that `~/.gemini/AGENTS.md` is loaded **(verify)**.

### Codex: hand-made hook

First check the current content with `rtk init -g --codex --dry-run`. Copy **only** the `hooks.json` part. As of RTK 0.52.0 it is:

```bash
mkdir -p ~/.codex
[ -f ~/.codex/hooks.json ] && echo "hooks.json exists: merge by hand" || cat > ~/.codex/hooks.json <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Bash", "hooks": [ { "type": "command", "command": "rtk hook codex" } ] }
    ]
  }
}
EOF
```

If the hook never fires (no Codex commands in `rtk gain --history`), check whether your Codex version needs hooks enabled in `~/.codex/config.toml` **(verify)**.

### Copilot CLI: hand-made hook

Check with `rtk init -g --copilot --dry-run` and copy only the hook config. As of RTK 0.52.0:

```bash
mkdir -p ~/.copilot/hooks
cat > ~/.copilot/hooks/rtk-rewrite.json <<'EOF'
{
  "version": 1,
  "hooks": {
    "PreToolUse": [
      { "type": "command", "command": "rtk hook copilot", "cwd": ".", "timeout": 5 }
    ]
  }
}
EOF
```

### Devin: optional experimental hook (verify before relying on it)

- Devin supports Claude-style hooks under a `"hooks"` key in `~/.config/devin/config.json`, but its shell tool is called `exec`, not `Bash`.
- RTK's Claude hook ignores the tool name. Tested: it rewrote an `exec` call correctly.
- What's not confirmed is whether Devin passes the command under `tool_input.command` and honours `updatedInput`.

```bash
f=~/.config/devin/config.json; [ -f "$f" ] || echo '{}' > "$f"
jq -e '.hooks.PreToolUse' "$f" >/dev/null 2>&1 && echo "Devin already has PreToolUse hooks: merge by hand" || {
  tmp=$(mktemp) && jq '.hooks.PreToolUse = [{"matcher":"exec","hooks":[{"type":"command","command":"rtk hook claude"}]}]' "$f" > "$tmp" && mv "$tmp" "$f" && chmod 600 "$f"
}
```

- **Test it:** in Devin, ask **"run exactly `ls -la`, with no prefix"**. If `rtk gain --history` then shows an `ls` entry, the hook works.
- **Remove it** if it doesn't work: delete the `hooks.PreToolUse` entry.
- **Know the trade-off:** the hook can pre-approve commands that RTK considers allowed. If you want Devin to ask before every command, skip the hook; the prompt rule alone still saves tokens.

### Telemetry

RTK has a `telemetry` subcommand. Review it (`rtk telemetry --help`) and set consent according to company policy.

---

# 8. MCP servers in every agent

## 8.1 How it works

```text
~/.agents/mcp/servers.json
        |
        +-- mcp-sync.sh --> Claude: ~/.claude.json
        |              --> Devin: ~/.config/devin/mcp_config.json
        |              --> Codex: ~/.codex/config.toml
        |              --> Gemini: ~/.gemini/settings.json
        |              --> Cursor: ~/.cursor/mcp.json
        |              --> Copilot: ~/.copilot/mcp-config.json
        |
        +-- local server starts through:
            ~/.agents/mcp/bin/with-secrets <cmd> <args...>
                |
                +-- loads ~/.config/agents/secrets.env
                +-- expands ${VAR} placeholders
                +-- adds Homebrew / uv / nvm paths to PATH
                +-- execs the server
```

### Why this design

- Every agent config contains only paths and `${VAR}` placeholders, never a token.
- Agents disagree on environment-variable syntax; the wrapper avoids depending
  on each agent's expansion behavior.
- GUI-launched agents often do not inherit your shell PATH; the wrapper fixes PATH.
- Agent CLIs are used where the format is complex/shared with other state.
  Plain JSON files are merged carefully, touching only `mcpServers`.

## 8.2 Create the secrets file

```bash
mkdir -p ~/.config/agents && chmod 700 ~/.config/agents
cp ~/.agents/templates/secrets.env.example ~/.config/agents/secrets.env
chmod 600 ~/.config/agents/secrets.env
$EDITOR ~/.config/agents/secrets.env
```

The file is sourced by bash: one `NAME="value"` per line.

Recommended on macOS: keep token values in Keychain and fetch them at source
time, for example:

```bash
security add-generic-password -a "$USER" -s agents-example-token -w

# in secrets.env:
EXAMPLE_TOKEN="$(security find-generic-password -s agents-example-token -w)"
```

Because the file is executed, keep it private (`600`) and owned by you.

Check that a secret loads without printing it:

```bash
~/.agents/mcp/bin/with-secrets bash -c 'test -n "$EXAMPLE_TOKEN" && echo "EXAMPLE_TOKEN loaded"'
```

### Corporate network

Proxy and CA settings for MCP servers go in the same secrets/env file, for
example:

```bash
HTTPS_PROXY="http://proxy.example.com:8080"
HTTP_PROXY="$HTTPS_PROXY"
NO_PROXY="localhost,127.0.0.1"

NODE_EXTRA_CA_CERTS="$HOME/.rbc-machine-configurator/rbc-ca-bundle.cer"
REQUESTS_CA_BUNDLE="$HOME/.config/agents/ca-bundle.pem"
SSL_CERT_FILE="$HOME/.config/agents/ca-bundle.pem"
```

Node expects a CA list; Python `requests` expects a combined bundle.

## 8.3 Add servers to `servers.json`

`~/.agents/mcp/servers.json` uses the common `mcpServers` shape.

Typical local server:

```json
{
  "mcpServers": {
    "fetch": {
      "_comment": "Pin a version you've reviewed.",
      "command": "$HOME/.agents/mcp/bin/with-secrets",
      "args": ["uvx", "mcp-server-fetch"]
    }
  }
}
```

For your own server code in the hub:

```json
{
  "mcpServers": {
    "my-tool": {
      "command": "$HOME/.agents/mcp/bin/with-secrets",
      "args": [
        "uv",
        "run",
        "$HOME/.agents/mcp/servers/my-tool/server.py"
      ]
    }
  }
}
```

For a remote server with OAuth, preferred:

```json
{
  "mcpServers": {
    "vendor": {
      "type": "http",
      "url": "https://mcp.vendor.example/mcp"
    }
  }
}
```

Nothing secret is stored. After syncing, log in once in each agent.

| Agent | Login pattern |
|---|---|
| Claude Code | `claude mcp login vendor` or `/mcp` -> vendor -> Authenticate |
| Devin | `devin mcp login vendor` |
| Codex | `codex mcp login vendor` |
| Gemini | `/mcp auth vendor` |
| Cursor / Copilot | via MCP settings or `/mcp` screen |

### Static-token bridge

If a remote server requires a static token, bridge it through a local process
using `with-secrets` so the token never sits in any agent config.

The photographed example uses an npm bridge package such as `mcp-remote`,
passing an Authorization header from the environment. Prefer OAuth whenever
the server supports OAuth.

## 8.4 Sync to every agent

```bash
~/.agents/bin/mcp-sync.sh --dry-run
~/.agents/bin/mcp-sync.sh

MCP_SYNC_AGENTS="claude,devin" ~/.agents/bin/mcp-sync.sh
```

Start a **new session** (or restart the app) in each agent afterward.

The photographed behavior table indicates:

| Agent | Registration approach |
|---|---|
| Claude Code | `claude mcp remove -s user` + `claude mcp add-json -s user` |
| Devin CLI/Desktop | merge `~/.config/devin/mcp_config.json` |
| Codex CLI | `codex mcp remove` + `codex mcp add` |
| Gemini CLI | merge only the `mcpServers` key of `~/.gemini/settings.json` |
| Cursor | merge `~/.cursor/mcp.json` |
| Copilot CLI | merge `~/.copilot/mcp-config.json` |

Important behavior:

- Agent detection targets agents whose CLI is on `PATH` or whose config folder
  exists.
- It tracks names it created in `~/.config/agents/mcp-managed.txt`.
- Deleting a server from `servers.json` removes it from every agent on the next
  full sync.
- If one agent alone has a same-name server, `servers.json` wins on the next
  sync.
- Every changed file is copied to the backup directory first.
- The process is designed to be idempotent.

## 8.5 Permissions

Each agent asks before using an MCP tool. Pre-approval lists are agent-specific.
For Claude Code, for example, read-only MCP tools can be allowed in user
settings. Pre-approve only read-only tools.

## 8.6 Project-scoped MCP (optional)

Prefer the user-level setup above; it is global and written once.

If a repo genuinely needs a shared server, commit only a non-secret project
config and keep secrets in the user-level secret file. Never commit secret
values.

## 8.7 Verify

```bash
claude mcp list
devin mcp list
codex mcp list
gemini mcp list
```

Also verify Cursor/Copilot from their MCP screens.

In a session, ask:

> “Which MCP tools do you have? Call a read-only tool from `<server>`.”

To debug a local server:

```bash
~/.agents/mcp/bin/with-secrets uvx mcp-server-fetch
```

A missing secret should produce an explicit `with-secrets` error naming the
missing variable, not its value.

---

# 9. Project-level setup (per repo)

## 9.1 Standard layout

```text
repo/
├── AGENTS.md                       # single source of project rules
├── packages/foo/AGENTS.md          # optional nested rules
├── CLAUDE.md                       # OPTIONAL: only if you need Claude-only notes
└── .agents/skills/<name>/SKILL.md # project skills (Devin, Codex, natively)
    └── .claude/skills/<name>       # relative symlink for Claude
```

How agents pick up project `AGENTS.md`:

| Agent | Project rule behavior |
|---|---|
| Claude Code | native in recent versions when there is no `CLAUDE.md`; if a `CLAUDE.md` exists, start it with `@AGENTS.md` |
| Devin CLI/Desktop | native; also reads `CLAUDE.md` if present |
| Codex, Cursor, Copilot | native |
| Gemini CLI | via the global `context.fileName` setting |

## 9.2 New repo

```bash
cp ~/.agents/templates/AGENTS.project.md ./AGENTS.md
git add AGENTS.md && git commit -m "Add AGENTS.md for AI coding agents"
```

Keep it short and factual: what the repo is, exact build/test/lint commands,
structure, conventions, and boundaries.

## 9.3 Converting an existing CLAUDE.md-only repo

Example:

```bash
git mv CLAUDE.md AGENTS.md
# edit the first lines: "guidance to Claude Code" -> "guidance to AI coding agents"

# only if you need Claude-only notes:
printf '@AGENTS.md\n\n# Claude Code only\n' > CLAUDE.md

git add CLAUDE.md AGENTS.md
git commit -m "Move agent instructions to AGENTS.md (cross-agent standard)"
```

## 9.4 Project skills

```bash
mkdir -p .agents/skills/my-skill
$EDITOR .agents/skills/my-skill/SKILL.md

mkdir -p .claude/skills
ln -s ../../.agents/skills/my-skill .claude/skills/my-skill

git add .agents/skills .claude/skills
git commit -m "Add my-skill"
```

Relative symlinks work on macOS and Linux clones. On Windows, git needs
`core.symlinks=true`.

## 9.5 Project hooks and settings

There is no cross-agent standard for hooks or permissions yet. Keep project
hooks tool-specific and minimal.

---

# 10. Verification checklist

Run it in a scratch git repo:

```bash
mkdir -p /tmp/agent-check
cd /tmp/agent-check
git init
```

The photographed checklist tests:

1. **Global rules loaded**
2. **Project rules loaded**
3. **Personal skill visible**
4. **Superpowers skill visible**
5. **RTK working**
6. **MCP servers available**
7. **No secrets in configs**
8. **Hub unchanged**

Also check that no stale skill copies exist:

```bash
ls ~/.config/devin/skills 2>/dev/null
ls ~/.claude/skills-maxdepth 1 -type l -exec ls -l {} \;
```

---

# 11. Adding a new agent later

Your working agents stay as they are as long as you exist and re-creating hub
files would replace your `AGENTS.md` and `servers.json`.

## 11.1 An agent this guide covers

1. Install it manually, start it once, and log in.
2. Wire it:

```bash
~/.agents/bin/link.sh
```

3. Add only the new agent's RTK rule/hook from section 7.
4. MCP: sync only the new agent's row from section 8:

```bash
MCP_SYNC_AGENTS="<agent>" ~/.agents/bin/mcp-sync.sh --dry-run
MCP_SYNC_AGENTS="<agent>" ~/.agents/bin/mcp-sync.sh
```

5. Check it is in the new agent, and verify with section 10.
6. Commit any hub changes.

## 11.2 An agent this guide does not cover yet

Extend the hub first:

1. Global rules: find where it reads user-level instructions, then either
   symlink that location to `~/.agents/AGENTS.md` or use an import setting if
   the agent prefers one.
2. Project rules: check it reads `AGENTS.md`; if not, configure/import it.
3. Skills: if it does not read `~/.agents/skills`, add its skills folder as
   another link target in `link.sh`.
4. RTK: add its hook/init path or rely on the global prompt rule.
5. MCP: find its user-level config format and extend `mcp-sync.sh` with another
   translator.
6. Add the agent to this guide and the verification checklist.

---

# 12. Deliberately not covered

- Specific MCP servers you already run (Jira, Confluence, GitHub, web, etc.)
  are not hard-coded here. Bring one into the hub by adding it to
  `~/.agents/mcp/servers.json`, adding any needed secret names to
  `secrets.env`, then running `mcp-sync.sh`.
- Subagents are deliberately out of scope.
- Claude's synced skills and remote settings/policy are org-managed. Do not
  copy or edit them.
- Claude settings are intentionally kept tool-specific; do not share a
  generic settings file across agents because tool names differ.

---

# 13. Maintenance

| Task | How |
|---|---|
| Change global rules | edit `~/.agents/AGENTS.md`, commit; all agents pick it up next session |
| Add a personal skill | create `~/.agents/skills/<name>/SKILL.md`; run `~/.agents/bin/link.sh`; commit |
| Remove a skill | delete its folder, run `link.sh` (it prunes dangling links), commit |
| Update Superpowers | get a newer copy, run `superpowers-update.sh` dry-run first, review the diff, commit, run `link.sh` |
| Update RTK | `brew upgrade rtk`; then `rtk init --dry-run` for each hook to see whether the hook format changed |
| Add/change MCP server | edit `~/.agents/mcp/servers.json`, run `mcp-sync.sh --dry-run`, then `mcp-sync.sh`, commit |
| Remove an MCP server | delete it from `servers.json`, run `mcp-sync.sh`; managed entries are pruned |
| Rotate an MCP secret | update the Keychain item or `secrets.env`; restart the agent; no sync needed |
| Install a new agent | section 11.1 |
| Back up | `git -C ~/.agents push` if you added a remote, or zip `~/.agents` |

---

# 14. Troubleshooting

| Symptom | Likely cause / fix |
|---|---|
| Claude does not follow global rules | the import line is missing or wrong, or this is a Cowork session |
| Claude says it cannot edit `CLAUDE.md` | `~/.claude/CLAUDE.md` is a symlink; replace it with a real file containing the import |
| A skill appears twice | duplicated in both native/shared and agent-local skill folders; remove the real duplicate |
| A Superpowers skill is not found | check shared skills, run `link.sh`, restart a new session |
| Superpowers skill appears twice / hook appears at session start | plugin is still installed; remove the plugin and stale hook |
| Agent says `superpowers:*` is not found | skills are plain user skills now; invoke them by skill name |
| `rtk gain` shows nothing | hook not installed or agent ignores the prompt rule; inspect the RTK hook file |
| `rtk` commands are prefixed twice | hook and prompt both rewrote the same command; update hook/prompt behavior |
| Gemini ignores `AGENTS.md` | `context.fileName` missing, or RTK init changed it |
| MCP server failed to connect | command not found / wrong runtime / missing secret; run the server manually through `with-secrets` |
| `with-secrets: ${NAME} is not set` | add the named variable to the private secret file |
| MCP server says unauthorized | OAuth login not done in that agent |
| Remote MCP server errors from corporate CA | set `NODE_EXTRA_CA_CERTS` and/or a combined Python CA bundle |
| TLS/certificate errors from MCP servers | verify the CA bundle and proxy environment |

---

# 15. Reference: support matrix and sources

## Matrix

The photographed matrix marks support for:

- global rules
- project `AGENTS.md`
- global skills
- Superpowers
- RTK
- user-level MCP config
- project-level MCP config

across Claude Code, Devin CLI/Desktop, Codex CLI, Gemini CLI, Cursor, and
Copilot CLI.

A green check in the original document means confirmed from fetched
documentation or tested locally on 2026-10-30. Other entries come from
secondary sources and should be verified on first use.

## Sources listed in the photographed document

- AGENTS.md standard: `https://agents.md`
- Claude Code memory/imports and `AGENTS.md`
- Claude Code skills documentation
- Agent Skills standard
- Devin CLI skills, hooks, rules, and Claude compatibility docs
- Codex CLI hooks and MCP docs
- Superpowers source repo: `https://github.com/obra/superpowers`
- RTK: `https://github.com/rtk-ai/rtk`
- MCP specification
- Claude Code MCP documentation
- Devin CLI MCP documentation
- MCP Remote static bridge
- Multi-agent config generators such as RuleSync / Ruler

## Tested locally

The photographed notes say the setup was tested locally on 2026-10-30,
including:

- `rtk init --dry-run` for Claude, Codex, Gemini, Cursor, and Copilot
- command rewriting such as `git status` -> `rtk git status`
- Devin experimental `exec` hook behavior
- `with-secrets` environment expansion
- `mcp-sync.sh` dry-run and idempotence
- merging/pruning only managed MCP servers
- Claude and Codex MCP add/remove behavior
- Superpowers update and conflict handling

---

# 16. Appendix: file templates

## 16.1 Global `AGENTS.md`

Save as `~/.agents/AGENTS.md`.

```markdown
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
```

## 16.2 `bin/link.sh`

Save as `~/.agents/bin/link.sh`, then:

```bash
chmod +x ~/.agents/bin/link.sh
```

```bash
#!/usr/bin/env bash
# Link.sh: wire ~/.agents (the hub) into every installed AI coding agent.
# Idempotent: safe to re-run after adding skills or installing a new agent.
# Never overwrites real files without backing them up; never touches org-managed dirs.
set -euo pipefail

HUB="${AGENTS_HUB:-$HOME/.agents}"
RULES="$HUB/AGENTS.md"
BACKUP_DIR="${BACKUP_DIR:-/private/tmp/ai-setup-backup-$(date +%Y%m%d-%H%M%S)}"

[ -f "$RULES" ] || { echo "error: $RULES not found" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

backup() {
  local path="$1" dest="$BACKUP_DIR${1#$HOME}"
  mkdir -p "$(dirname "$dest")"
  mv "$path" "$dest"
  echo "backed up: $path -> $dest"
}

link_file() {
  local target="$1" link="$2"
  mkdir -p "$(dirname "$link")"

  if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
    echo "ok:      $link"
    return
  fi

  if [ -e "$link" ] || [ -L "$link" ]; then
    backup "$link"
  fi

  ln -sfn "$target" "$link"
  echo "linked:  $link -> $target"
}

link_skills() {
  local src_root="$1" dst_root="$2"
  [ -d "$src_root" ] || return 0
  mkdir -p "$dst_root"

  for src in "$src_root"/*; do
    [ -d "$src" ] || continue
    name="$(basename "$src")"
    dst="$dst_root/$name"

    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
      echo "skip:    $dst is a real folder (remove it if the hub copy should win)" >&2
      continue
    fi

    ln -sfn "$src" "$dst"
    echo "linked:  $dst -> $src"
  done
}

prune_links() {
  local dir="$1"
  [ -d "$dir" ] || return 0

  find "$dir" -maxdepth 1 -type l | while read -r l; do
    case "$(readlink "$l")" in
      "$HUB"/*)
        [ -e "$l" ] || { rm "$l"; echo "pruned: $l"; }
        ;;
    esac
  done
}

# 1. Claude Code: real CLAUDE.md that imports the hub (never a symlink).
if has claude || [ -d "$HOME/.claude" ]; then
  mkdir -p "$HOME/.claude"
  CMD="$HOME/.claude/CLAUDE.md"

  if [ -L "$CMD" ]; then
    backup "$CMD"
  fi

  if [ ! -e "$CMD" ]; then
    printf '@~/.agents/AGENTS.md\n\n# Claude Code only\n' > "$CMD"
    echo "created: $CMD"
  elif ! grep -qF '@~/.agents/AGENTS.md' "$CMD"; then
    echo "NOTE: add the line @~/.agents/AGENTS.md to the top of $CMD yourself" >&2
  else
    echo "ok:      $CMD"
  fi

  link_skills "$HUB/skills" "$HOME/.claude/skills"
  prune_links "$HOME/.claude/skills"
fi

# 2. Devin CLI + Devin Desktop
if has devin || [ -d "$HOME/.config/devin" ]; then
  link_file "$RULES" "$HOME/.config/devin/AGENTS.md"
fi

# 3. Codex CLI
if has codex || [ -d "$HOME/.codex" ]; then
  link_file "$RULES" "$HOME/.codex/AGENTS.md"
fi

# 4. Gemini CLI
if has gemini || [ -d "$HOME/.gemini" ]; then
  link_file "$RULES" "$HOME/.gemini/AGENTS.md"
  # Uncomment if Gemini does not list ~/.agents/skills natively:
  # link_skills "$HUB/skills" "$HOME/.gemini/skills"
fi

# 5. Copilot CLI
if has copilot || [ -d "$HOME/.copilot" ]; then
  link_file "$RULES" "$HOME/.copilot/copilot-instructions.md"
fi

# 6. Cursor: user rules are UI-only; paste ~/.agents/AGENTS.md into Settings -> Rules.

[ -d "$BACKUP_DIR" ] && \
  echo "backups in: $BACKUP_DIR (macOS clears /private/tmp on reboot)"
echo "done."
```

## 16.3 Project `AGENTS.md` starter

Save as `~/.agents/templates/AGENTS.project.md`.

```markdown
# AGENTS.md

Guidance for AI coding agents working in this repository.

## Overview

One short paragraph: what this repo does and its main components.

## Setup and commands

- Install: `uv sync`
- Test: `uv run pytest`
- Single test: `uv run pytest path/to/test_file.py::test_name`
- Lint and format: `uv run ruff check . && uv run ruff format .`
- Run locally: `<command>`

## Structure

- `src/<pkg>/`: ...
- `tests/`: ...

## Conventions

- ...

## Boundaries

- Don't edit generated files in `<...>`.
- Ask before changing CI config, database migrations, or dependency versions.
```

## 16.4 Hub `.gitignore`

Save as `~/.agents/.gitignore`.

```gitignore
.DS_Store
*.bak
.env
*.env
secrets*
!templates/secrets.env.example
```

## 16.5 `mcp/servers.json`

Save as `~/.agents/mcp/servers.json`.

```json
{
  "_comment": "MCP servers for every agent. No secrets here; put them in ~/.config/agents/secrets.env and reference them as ${NAME} in args. After editing run ~/.agents/bin/mcp-sync.sh --dry-run && ~/.agents/bin/mcp-sync.sh.",
  "mcpServers": {
    "fetch": {
      "_comment": "Example (Pattern A). Delete it if you don't want it; pin a version you've reviewed.",
      "command": "$HOME/.agents/mcp/bin/with-secrets",
      "args": ["uvx", "mcp-server-fetch"]
    }
  }
}
```

## 16.6 `mcp/bin/with-secrets`

Save as `~/.agents/mcp/bin/with-secrets`, then `chmod +x ~/.agents/mcp/bin/with-secrets`.

```bash
#!/usr/bin/env bash
# with-secrets: start an MCP server with secrets loaded from a private env file.
#   In servers.json: "command": "$HOME/.agents/mcp/bin/with-secrets", "args": ["<cmd>", "<arg>", ...]
# - exports every variable defined in $AGENTS_SECRETS (default ~/.config/agents/secrets.env)
# - expands ${VAR} inside arguments (agents pass args literally, without a shell)
# - extends PATH, because GUI-launched agents often start servers with a minimal PATH
set -euo pipefail

SECRETS="${AGENTS_SECRETS:-$HOME/.config/agents/secrets.env}"

PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"
if [ -d "$HOME/.nvm/versions/node" ]; then
  latest_node="$(ls -1 "$HOME/.nvm/versions/node" | sort -V | tail -1)"
  [ -n "$latest_node" ] && PATH="$HOME/.nvm/versions/node/$latest_node/bin:$PATH"
fi
export PATH

if [ -f "$SECRETS" ]; then
  set -a; . "$SECRETS"; set +a
fi

expand() {   # replace every ${NAME} in $1 with the value of $NAME
  local s="$1" out="" name re='^(([^$]|\$[^\{])*)\$\{([A-Za-z_][A-Za-z0-9_]*)\}(.*)$'
  while [[ $s =~ $re ]]; do
    out+="${BASH_REMATCH[1]}"
    name="${BASH_REMATCH[3]}"
    [ -n "${!name+x}" ] || { echo "with-secrets: \${$name} is not set (check $SECRETS)" >&2; return 1; }
    out+="${!name}"
    s="${BASH_REMATCH[4]}"
  done
  printf '%s' "$out$s"
}

[ $# -gt 0 ] || { echo "usage: with-secrets <command> [args...]" >&2; exit 2; }
args=()
for a in "$@"; do args+=("$(expand "$a")"); done
exec "${args[@]}"
```

## 16.7 `templates/secrets.env.example`

Save as `~/.agents/templates/secrets.env.example`. It contains names only, so it is safe to commit. Copy it to `~/.config/agents/secrets.env` and fill that copy in (section 8.2).

```bash
# ~/.config/agents/secrets.env: private MCP secrets, chmod 600, NEVER commit it.
# Sourced by bash ~/.agents/mcp/bin/with-secrets right before each MCP server starts.
# Format: NAME="value". Servers see these as environment variables, and
# ${NAME} inside servers.json "args" is replaced with the value.

# --- Plain value (simple, but stored on disk in clear text) ---
# EXAMPLE_API_URL="https://api.example.com"

# --- macOS Keychain (recommended for tokens) ---
#   store once: security add-generic-password -a "$USER" -s agents-example-token -w
# EXAMPLE_TOKEN="$(security find-generic-password -s agents-example-token -w)"

# --- Corporate network (only if your servers need it) ---
# HTTPS_PROXY="http://proxy.example.com:8080"

# HTTP_PROXY="$HTTPS_PROXY"
# NO_PROXY="localhost,127.0.0.1"
# NODE_EXTRA_CA_CERTS="$HOME/.rbc-machine-configurator/rbc-ca-bundle.cer"    # Node: ADDS the corporate CA
# REQUESTS_CA_BUNDLE="$HOME/.config/agents/ca-bundle.pem"                    # Python requests: needs a COMBINED bundle
# SSL_CERT_FILE="$HOME/.config/agents/ca-bundle.pem"
```

### 16.8 `bin/mcp-sync.sh`

Save as `~/.agents/bin/mcp-sync.sh`, then `chmod +x ~/.agents/bin/mcp-sync.sh`.

```bash
#!/usr/bin/env bash
# mcp-sync.sh: register every MCP server in ~/.agents/mcp/servers.json with each installed agent.
#
#   mcp-sync.sh              apply
#   mcp-sync.sh --dry-run    show what would change; writes nothing, calls no agent CLI
#   MCP_SYNC_AGENTS="claude devin" mcp-sync.sh     # only these agents
#                         (claude devin codex gemini cursor copilot)
#                         Servers removed from servers.json stay recorded until a full
#                         sync, so the agents left out are pruned then.
#
# Idempotent. It manages only the servers it created (names tracked in
# ~/.config/agents/mcp-managed.txt). Servers you added by hand in an agent are left
# alone, unless they have the same name as one in servers.json; servers.json wins.
set -euo pipefail

HUB="${AGENTS_HUB:-$HOME/.agents}"
SRC="$HUB/mcp/servers.json"
STATE_DIR="${AGENTS_STATE:-$HOME/.config/agents}"
STATE="$STATE_DIR/mcp-managed.txt"
BACKUP_DIR="${BACKUP_DIR:-/private/tmp/ai-setup-backup-$(date +%Y%m%d-%H%M%S)}"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1

command -v jq >/dev/null 2>&1 || { echo "error: jq is required (brew install jq)" >&2; exit 1; }
[ -f "$SRC" ] || { echo "error: $SRC not found" >&2; exit 1; }

# Expand a leading $HOME in every string; drop keys starting with "_" (used as comments).
RESOLVED="$(jq --arg home "$HOME" '
  walk(if type == "object" then with_entries(select(.key | startswith("_") | not))
       elif type == "string" then sub("^\\$HOME"; $home)
       else . end)' "$SRC")"

CURRENT="$(jq -r '.mcpServers // {} | keys[]' <<<"$RESOLVED")"
PREVIOUS=""; [ -f "$STATE" ] && PREVIOUS="$(cat "$STATE")"
REMOVED="$(comm -23 <(printf '%s\n' "$PREVIOUS" | sed '/^$/d' | sort -u) \
                  <(printf '%s\n' "$CURRENT"  | sed '/^$/d' | sort -u))"
REMOVED_JSON="$(printf '%s\n' "$REMOVED" | jq -R . | jq -s 'map(select(length > 0))')"

# Per-agent translations of one server entry (input: the entry from servers.json).
JQ_DEFS='
def kind: if has("command") then "stdio" else (.type // "http") end;
def stdio: {command, args: (.args // []), env: (.env // {})};
def to_claude: if kind == "stdio" then {type: "stdio"} + stdio
               else {type: kind, url, headers: (.headers // {})} end;
def to_devin:  if kind == "stdio" then stdio
               else {url, transport: kind, headers: (.headers // {})} end;
def to_gemini: if kind == "stdio" then stdio
               elif kind == "sse" then {url, headers: (.headers // {})}
               else {httpUrl: .url, headers: (.headers // {})} end;
def to_cursor: if kind == "stdio" then stdio
               else {url, headers: (.headers // {})} end;
def to_copilot: if kind == "stdio" then {type: "local"} + stdio + {tools: ["*"]}
                else {type: kind, url, headers: (.headers // {}), tools: ["*"]} end;
'

want() {   # want <agent> <cli> <config-dir>
  if [ -n "${MCP_SYNC_AGENTS:-}" ]; then
    case " $MCP_SYNC_AGENTS " in *" $1 "*) return 0 ;; *) return 1 ;; esac
  fi
  command -v "$2" >/dev/null 2>&1 || [ -d "$3" ]
}

backup_copy() {   # copy a file into BACKUP_DIR (same relative path) before changing it
  [ -f "$1" ] || return 0
  local dest="$BACKUP_DIR${1#$HOME}"
  mkdir -p "$(dirname "$dest")" && cp -p "$1" "$dest"
}

merge_json() {   # merge_json <label> <file> <translator>: for agents configured by a JSON file
  local label="$1" file="$2" fn="$3" current='{}' result
  [ -s "$file" ] && current="$(cat "$file")"
  result="$(jq --argjson src "$RESOLVED" --argjson removed "$REMOVED_JSON" "$JQ_DEFS
    .mcpServers = (
      ((.mcpServers // {}) | with_entries(select(.key as \$k | any(\$removed[]; . == \$k) | not)))
      + ((\$src.mcpServers // {}) | map_values($fn))
    )" <<<"$current")" ||
    { echo "error: could not build $file" >&2; return 1; }

  if [ "$DRY" = 1 ]; then
    echo "—— $label: $file would have mcpServers:"; jq '.mcpServers' <<<"$result"; return 0
  fi
  backup_copy "$file"
  mkdir -p "$(dirname "$file")"
  printf '%s\n' "$result" > "$file.tmp.$$"
  cat "$file.tmp.$$" > "$file" && rm -f "$file.tmp.$$"   # keeps the file's permissions
  echo "updated: $label ($file)"
}

entry() { jq -c --arg n "$1" "$JQ_DEFS .mcpServers[\$n] | $2" <<<"$RESOLVED"; }

sync_claude() {   # via the claude CLI (never edit ~/.claude.json by hand)
  local n
  [ "$DRY" = 1 ] || backup_copy "$HOME/.claude.json"
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    if [ "$DRY" = 1 ]; then echo "—— claude: claude mcp remove -s user $n"; continue; fi
    claude mcp remove -s user "$n" >/dev/null 2>&1 || true
    echo "removed: claude ($n)"
  done <<<"$REMOVED"

  while IFS= read -r n; do
    [ -n "$n" ] || continue
    if [ "$DRY" = 1 ]; then echo "—— claude: claude mcp add-json -s user $n '$(entry "$n" to_claude)'"; continue; fi
    claude mcp remove -s user "$n" >/dev/null 2>&1 || true
    claude mcp add-json -s user "$n" "$(entry "$n" to_claude)" >/dev/null
    echo "updated: claude ($n)"
  done <<<"$CURRENT"
}

sync_codex() {   # via the codex CLI (config is TOML)   (verify flags with: codex mcp add --help)
  local n kv a
  [ "$DRY" = 1 ] || backup_copy "$HOME/.codex/config.toml"
  while IFS= read -r n; do
    [ -n "$n" ] || continue
    if [ "$DRY" = 1 ]; then echo "—— codex: codex mcp remove $n"; continue; fi
    codex mcp remove "$n" >/dev/null 2>&1 || true
    echo "removed: codex ($n)"
  done <<<"$REMOVED"

  while IFS= read -r n; do
    [ -n "$n" ] || continue
    local cmd=(codex mcp add "$n")
    if [ "$(entry "$n" kind)" = '"stdio"' ]; then
      while IFS= read -r kv; do [ -n "$kv" ] && cmd+=(--env "$kv"); done \
        < <(jq -r --arg n "$n" '.mcpServers[$n].env // {} | to_entries[] | "\(.key)=\(.value)"' <<<"$RESOLVED")
      cmd+=(--)
      while IFS= read -r a; do cmd+=("$a"); done \
        < <(jq -r --arg n "$n" '.mcpServers[$n] | .command, (.args // [])[]' <<<"$RESOLVED")
    else
      cmd+=(--url "$(jq -r --arg n "$n" '.mcpServers[$n].url' <<<"$RESOLVED")")
    fi
    if [ "$DRY" = 1 ]; then printf '—— codex:'; printf ' %q' "${cmd[@]}"; echo; continue; fi
    codex mcp remove "$n" >/dev/null 2>&1 || true
    "${cmd[@]}" >/dev/null
    echo "updated: codex ($n)"
  done <<<"$CURRENT"
}

[ "$DRY" = 1 ] && echo "DRY RUN: nothing will be written" && echo "removed since last sync: $(printf '%s' "${REMOVED:-<none>}" | tr '\n' ' ')"

want claude  claude  "$HOME/.claude"        && sync_claude
want devin   devin   "$HOME/.config/devin" && merge_json devin   "$HOME/.config/devin/mcp_config.json" to_devin
want codex   codex   "$HOME/.codex"         && sync_codex
want gemini  gemini  "$HOME/.gemini"        && merge_json gemini  "$HOME/.gemini/settings.json"        to_gemini
want cursor  cursor  "$HOME/.cursor"        && merge_json cursor  "$HOME/.cursor/mcp.json"              to_cursor
want copilot copilot "$HOME/.copilot"       && merge_json copilot "$HOME/.copilot/mcp-config.json"      to_copilot

if [ "$DRY" = 0 ]; then
  mkdir -p "$STATE_DIR"
  if [ -n "${MCP_SYNC_AGENTS:-}" ] && [ -n "$REMOVED" ]; then
    printf '%s\n%s\n' "$CURRENT" "$REMOVED" | sed '/^$/d' | sort -u > "$STATE"
    echo "note: partial sync; removed servers $(printf '%s' "$REMOVED" | tr '\n' ' ') are pruned from the other agents on the next full sync"
  else
    printf '%s\n' "$CURRENT" > "$STATE"
  fi
  [ -d "$BACKUP_DIR" ] && echo "backups in: $BACKUP_DIR (macOS clears /private/tmp on reboot)"
fi

echo "done."
```

### 16.9 `bin/superpowers-update.sh`

Save as `~/.agents/bin/superpowers-update.sh`, then `chmod +x ~/.agents/bin/superpowers-update.sh`. Usage is in section 6.3.

```bash
#!/usr/bin/env bash
# superpowers-update.sh: copy the Superpowers skills into the hub's shared skills folder.
# No plugin, no session-start hook: the skills are plain skills you invoke by name.
#
# Usage: superpowers-update.sh [--dry-run] <superpowers-dir>
# <superpowers-dir> is any copy of Superpowers that contains skills/: a git clone of
# github.com/obra/superpowers, an unzipped release, or an installed plugin folder.
#
# Only skills recorded in third_party/superpowers/skills.txt are ever replaced or
# removed. Your own skills in ~/.agents/skills are never touched.
# SUPERPOWERS_SKIP="name1 name2" leaves those skills out (and removes them if present).
set -euo pipefail

DRY=0
if [ "${1:-}" = "--dry-run" ]; then DRY=1; shift; fi
SRC="${1:?usage: superpowers-update.sh [--dry-run] <superpowers-dir>}"
SRC="${SRC%/}"
HUB="${AGENTS_HUB:-$HOME/.agents}"
SKILLS="$HUB/skills"
META="$HUB/third_party/superpowers"
LIST="$META/skills.txt"
SKIP="${SUPERPOWERS_SKIP:-} "

[ -d "$SRC/skills" ] || { echo "error: $SRC/skills not found" >&2; exit 1; }

VERSION=unknown
for m in package.json .claude-plugin/plugin.json .codex-plugin/plugin.json; do
  v=$(jq -r '.version // empty' "$SRC/$m" 2>/dev/null || true)
  if [ -n "$v" ]; then VERSION="$v"; break; fi
done

say() { if [ "$DRY" = 1 ]; then echo "would $*"; else echo "$*"; fi; }
in_list() { printf '%s\n' "$2" | grep -qxF "$1"; }

old=""
if [ -f "$LIST" ]; then old=$(cat "$LIST"); fi
new=""
[ "$DRY" = 1 ] || mkdir -p "$SKILLS"

for d in "$SRC"/skills/*/; do
  d="${d%/}"; name=$(basename "$d")
  [ -f "$d/SKILL.md" ] || continue
  case " $SKIP " in *" $name "*) continue ;; esac
  dst="$SKILLS/$name"
  if [ -e "$dst" ] && [ ! -L "$dst" ] && ! in_list "$name" "$old"; then
    echo "conflict: $dst exists and isn't from Superpowers; left alone" >&2; continue
  fi
  new="$new$name
"

  if [ -d "$dst" ] && [ ! -L "$dst" ] && diff -rq "$d" "$dst" >/dev/null 2>&1; then
    echo "ok:      $name"; continue
  fi
  if [ -d "$dst" ] || [ -L "$dst" ]; then say "update: $name"; else say "add:    $name"; fi
  if [ "$DRY" = 0 ]; then rm -rf "$dst"; cp -Rp "$d" "$dst"; fi
done

# Remove skills that came from Superpowers before but are gone upstream or now skipped
while IFS= read -r name; do
  case "$name" in ""|..|*/*) continue ;; esac
  in_list "$name" "$new" && continue
  if [ -e "$SKILLS/$name" ] || [ -L "$SKILLS/$name" ]; then
    say "remove: $name"
    [ "$DRY" = 1 ] || rm -rf "${SKILLS:?}/$name"
  fi
done <<EOF
$old
EOF

if [ "$DRY" = 1 ]; then
  echo "dry run: nothing written (Superpowers $VERSION from $SRC)"
  exit 0
fi

mkdir -p "$META"
printf '%s' "$new" > "$LIST"
echo "$VERSION" > "$META/VERSION"
if [ -f "$SRC/LICENSE" ]; then cp "$SRC/LICENSE" "$META/LICENSE"; fi
echo "Superpowers $VERSION: $(printf '%s' "$new" | grep -c .) skills in $SKILLS"
echo "next: git -C \"$HUB\" diff --stat, commit, then run bin/link.sh"
```
