# willown-code

La mia configurazione di [Claude Code](https://claude.com/claude-code), versionata.
La cartella `~/.claude` è il repo stesso: cloni, fai login, e tutto è al suo posto.

```
Ciao, Alessandro | Opus 5.5 | Context ████░░░░░░ 42% | Usage ██░░░░░░░░ 18% | ● GitHub: Will0wn | build 11
```

## Statusline

Uno script PowerShell che Claude Code richiama a ogni aggiornamento della barra. Da sinistra:

- saluto con il nome dell'account Claude
- modello in uso
- contesto occupato: verde sotto il 50%, giallo fino all'80%, rosso oltre
- utilizzo della finestra di 5 ore
- account GitHub attivo sulla macchina
- numero di commit di questo repo, come numero di build

Serve PowerShell 7 (`pwsh`) e un terminale con truecolor, ad esempio Windows Terminal.

## Installazione

Su un PC nuovo:

```bash
gh repo clone Will0wn/willown-code ~/.claude
```

Poi avvia Claude Code e fai login: le credenziali non sono nel repo.

Se `~/.claude` esiste già, adotta il repo senza toccare i file locali:

```bash
cd ~/.claude
git init -b master
git remote add origin https://github.com/Will0wn/willown-code.git
git fetch origin
git reset --mixed origin/master
git checkout origin/master -- .
git branch --set-upstream-to=origin/master master
```

## Aggiornare

```bash
cd ~/.claude
git pull --ff-only                               # scarica l'ultima versione
git add -A && git commit -m "..." && git push    # salva le modifiche
```

## Contenuto

| File | A cosa serve |
|------|--------------|
| `settings.json` | impostazioni globali: statusline, tema, aggiornamenti |
| `statusline.ps1` | la barra di stato |
| `CLAUDE.md` | istruzioni operative per Claude su questo repo |
| `.gitignore` | whitelist dei file versionati |

## Sicurezza

Il `.gitignore` parte da `/*` e riammette solo i file della tabella. Credenziali, cronologia,
sessioni e cache restano fuori, anche quelli che Claude Code creerà in futuro.
Per versionare un nuovo file serve una riga esplicita `!/<file>`.
