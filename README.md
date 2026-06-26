# Willown Code — Backup configurazione Claude Code

Backup **privato** della configurazione globale di [Claude Code](https://claude.com/claude-code).
La cartella `~/.claude` **è essa stessa** questo repo git: su ogni PC si lavora sempre dalla
stessa cartella, senza copiare file a mano.

Per sicurezza il repo versiona **solo** la configurazione non sensibile. Tutto il resto
(credenziali OAuth, cronologia, sessioni, cache, plugin) è escluso tramite una whitelist
nel [`.gitignore`](.gitignore).

## Contenuto del repo

| File | Descrizione |
|------|-------------|
| `settings.json` | Configurazione globale (tema, statusline, canale aggiornamenti) |
| `statusline.ps1` | Script PowerShell della barra di stato (saluto, modello, contesto, usage, remoto git, build N) |
| `.gitignore` | Whitelist: ignora tutto tranne i file sopra |
| `README.md` | Questo file |

> L'indicatore **`build N`** nella statusline mostra il numero totale di commit di questo
> repo di configurazione. Il conteggio usa `$PSScriptRoot` (la cartella che contiene lo
> script): poiché `~/.claude` è il repo, funziona automaticamente senza percorsi fissi.

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

La cartella `~/.claude` **è** il repo: si clona direttamente lì, senza copiare file a mano.

**PC pulito** (la cartella `~/.claude` non esiste ancora):

```bash
gh repo clone Will0wn/willown-code ~/.claude
```

**Cartella `~/.claude` già esistente** (creata da Claude Code) — adotta il repo senza
perdere i file locali (credenziali, sessioni e cache restano dove sono, e sono ignorati):

```bash
cd ~/.claude
git init -b master
git remote add origin https://github.com/Will0wn/willown-code.git
git fetch origin
git reset --mixed origin/master                # adotta la storia, working tree intatto
git checkout origin/master -- README.md        # porta i file versionati mancanti
git branch --set-upstream-to=origin/master master
```

### Note importanti per il ripristino

- **Login**: su un PC nuovo va rifatto il login di Claude Code — le credenziali OAuth
  **non** sono nel repo (per sicurezza).
- **Path della statusline**: in `settings.json` il comando punta a `~/.claude/statusline.ps1`
  (path portabile con `~`), quindi è **identico su ogni PC** — nessuna modifica manuale anche
  se il nome utente è diverso.
- **Requisiti statusline**: PowerShell 7+ (`pwsh`) nel PATH e un terminale con supporto
  truecolor (es. Windows Terminal) per i colori.
