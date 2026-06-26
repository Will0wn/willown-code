# Istruzioni operative — repo di configurazione Claude Code

Questo repo (`Will0wn/willown-code`) **È** la cartella `~/.claude`. Queste sono regole
operative da seguire, non descrizioni. Rispettale alla lettera.

## Dove vive il repo

- Il repo va **sempre** adottato o clonato come `~/.claude` (la home dell'utente, es.
  `C:\Users\<utente>\.claude`). La cartella `~/.claude` e il repo git sono la stessa cosa.
- **Mai** clonarlo o copiarlo in `Desktop/Workspace`, in sottocartelle di progetto o
  altrove. Una copia fuori da `~/.claude` non è "il setup": è ridondante e va rimossa.
- Se trovi una copia del repo fuori da `~/.claude`, rimuovila dopo aver verificato che
  `~/.claude` sia il repo allineato al remote.

## "Installare / attivare" la barra di stato

La statusline è attiva **solo** quando i file stanno in `~/.claude`:

- `settings.json` punta a `~/.claude/statusline.ps1` (path portabile, identico su ogni PC).
- Per attivarla NON serve copiare file altrove: basta che `~/.claude` sia il repo.
- Per verificarla, eseguila come fa Claude Code, passando un JSON di sessione su stdin:

  ```bash
  echo '{"model":{"display_name":"Opus 4.8"},"context_window":{"used_percentage":42},"rate_limits":{"five_hour":{"used_percentage":18}},"session_id":"test"}' \
    | pwsh -NoProfile -File ~/.claude/statusline.ps1
  ```

  Deve stampare: saluto (`Ciao, <Nome>`), modello, Context, Usage, indicatore GitHub
  (`● GitHub: <account>`) e `build N`.

## Aggiornare il backup (push)

Dopo aver modificato la configurazione:

```bash
cd ~/.claude
git add -A
git commit -m "<messaggio>"
git push
```

## Allineare al remote (pull)

Per portare `~/.claude` all'ultima versione del backup:

```bash
cd ~/.claude
git pull --ff-only origin master
```

Con working tree pulito è un fast-forward: aggiorna **solo** i file versionati. I file
ignorati (credenziali, sessioni, cache) non vengono toccati.

## Sicurezza — il `.gitignore` protegge le credenziali

- Il `.gitignore` è una **whitelist**: `/*` ignora tutto, poi `!` riammette solo i file
  voluti (`.gitignore`, `README.md`, `settings.json`, `statusline.ps1`, `CLAUDE.md`).
- Qualsiasi file non in whitelist — incluse credenziali e config locali — è **escluso** per
  default, anche se aggiunto in futuro.
- **Prima di ogni `git add`** verifica che la whitelist sia presente nel `.gitignore` e che
  i file sensibili (`.credentials.json`, `.claude.json`, `*credentials*.json`,
  `settings.local.json`, `history.jsonl`, ...) risultino ignorati:

  ```bash
  git check-ignore .credentials.json .claude.json settings.local.json   # devono comparire
  git ls-files                                                           # solo i file in whitelist
  ```
- Per aggiungere un nuovo file al repo, inseriscilo **esplicitamente** in whitelist con una
  riga `!/<file>` nel `.gitignore`. Non rimuovere mai le esclusioni di sicurezza.
