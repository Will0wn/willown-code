# Willown Code — Backup configurazione Claude Code

Backup **privato** della configurazione globale di [Claude Code](https://claude.com/claude-code)
(cartella `~/.claude`), per ripristinarla su altri PC.

Per sicurezza il repo versiona **solo** la configurazione non sensibile. Tutto il resto
(credenziali OAuth, cronologia, sessioni, cache, plugin) è escluso tramite una whitelist
nel [`.gitignore`](.gitignore).

## Contenuto del repo

| File | Descrizione |
|------|-------------|
| `settings.json` | Configurazione globale (tema, statusline, canale aggiornamenti) |
| `statusline.ps1` | Script PowerShell della barra di stato (saluto, modello, contesto, usage, remoto git) |
| `.gitignore` | Whitelist: ignora tutto tranne i file sopra |
| `README.md` | Questo file |

## Cosa NON è versionato (di proposito)

`.credentials.json` (token OAuth), `history.jsonl` (cronologia), `settings.local.json`,
`projects/`, `sessions/`, `session-env/`, `shell-snapshots/`, `file-history/`,
`paste-cache/`, `cache/`, `downloads/`, `backups/`, `plugins/`.

## Aggiornare il backup

Dopo aver modificato la configurazione:

```bash
cd ~/.claude
git add -A
git commit -m "Aggiorna configurazione"
git push
```

## Ripristinare su un nuovo PC

> Richiede `git` e (consigliato) [GitHub CLI](https://cli.github.com/) autenticato sul
> proprio account: `gh auth login --web`.

```bash
# 1) Clona il backup in una cartella temporanea
gh repo clone Will0wn/willown-code ~/willown-code-restore

# 2) Copia i file di configurazione nella ~/.claude del nuovo PC
cp ~/willown-code-restore/settings.json   ~/.claude/
cp ~/willown-code-restore/statusline.ps1  ~/.claude/
```

### Note importanti per il ripristino

- **Login**: su un PC nuovo va rifatto il login di Claude Code — le credenziali OAuth
  **non** sono nel repo (per sicurezza).
- **Path assoluto della statusline**: in `settings.json` il comando della statusline punta a
  un percorso assoluto (es. `C:/Users/<utente>/.claude/statusline.ps1`). Se sul nuovo PC il
  nome utente è diverso, aggiorna quel percorso.
- **Requisiti statusline**: PowerShell 7+ (`pwsh`) nel PATH e un terminale con supporto
  truecolor (es. Windows Terminal) per i colori.
