# willown-code

My [Claude Code](https://claude.com/claude-code) setup, under version control.
The `~/.claude` folder is the repo itself: clone it, log in, and everything is in place.

```
Ciao, Nome | Opus 5.5 | Context ████░░░░░░ 42% | Usage ██░░░░░░░░ 18% | ● GitHub: Will0wn | build 11
```

## Statusline

A PowerShell script that Claude Code calls every time the bar refreshes. From left to right:

- a greeting with the Claude account's name
- the current model
- context usage: green below 50%, yellow up to 80%, red above
- usage of the 5-hour window
- the GitHub account active on the machine
- the commit count of this repo, as a build number

Requires PowerShell 7 (`pwsh`) and a truecolor terminal, such as Windows Terminal.

## Install

On a new machine:

```bash
gh repo clone Will0wn/willown-code ~/.claude
```

Then start Claude Code and log in: credentials are not in the repo.

If `~/.claude` already exists, adopt the repo without touching local files:

```bash
cd ~/.claude
git init -b master
git remote add origin https://github.com/Will0wn/willown-code.git
git fetch origin
git reset --mixed origin/master
git checkout origin/master -- .
git branch --set-upstream-to=origin/master master
```

## Update

```bash
cd ~/.claude
git pull --ff-only                               # get the latest version
git add -A && git commit -m "..." && git push    # save your changes
```

## Contents

| File | Purpose |
|------|---------|
| `settings.json` | global settings: statusline, theme, updates |
| `statusline.ps1` | the status bar |
| `CLAUDE.md` | operating instructions for Claude on this repo |
| `.gitignore` | whitelist of tracked files |

## Security

The `.gitignore` starts from `/*` and re-includes only the files in the table. Credentials,
history, sessions and cache stay out, including anything Claude Code creates in the future.
Tracking a new file requires an explicit `!/<file>` line.
