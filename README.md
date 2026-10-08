# willown-code

My [Claude Code](https://claude.com/claude-code) setup, under version control.
The `~/.claude` folder is the repo itself: clone it, log in, and everything is in place.

![Statusline preview](statusline-preview.svg)

## Statusline

A PowerShell script that Claude Code runs every second. Next to a pixel-art devil that sways
and blinks like a tamagotchi, it shows:

1. greeting and the commit count of this repo as a build number
2. model and effort level, context usage (green below 50%, yellow up to 80%, red above),
   usage of the 5-hour window with reset time and countdown
3. the current folder and the GitHub account active on the machine
4. the connected MCP servers, loaded in the background once per session

Requires PowerShell 7 (`pwsh`) and a truecolor terminal, such as Windows Terminal.

## Install

The easiest way:

1. Download the ZIP: **Code > Download ZIP** on this page, then extract it.
2. Open Claude Code in the extracted folder and ask:

   > Install this statusline in my ~/.claude

Claude copies `statusline.ps1` into `~/.claude` and adds the `statusLine` entry to your
`settings.json`, keeping your existing settings.

### With git (to keep it in sync)

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
| `statusline-preview.svg` | the preview image above |
| `CLAUDE.md` | operating instructions for Claude on this repo |
| `.gitignore` | whitelist of tracked files |

## Security

The `.gitignore` starts from `/*` and re-includes only the files in the table. Credentials,
history, sessions and cache stay out, including anything Claude Code creates in the future.
Tracking a new file requires an explicit `!/<file>` line.
