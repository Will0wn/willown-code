[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$esc = [char]27
# palette truecolor (24-bit) -- un colore per tipo di informazione
$cCiao  = "$esc[1;38;2;167;139;250m"  # lavanda -> saluto (Ciao, Nome)
$cModel = "$esc[1;38;2;251;191;36m"   # ambra   -> modello
$cSep   = "$esc[38;2;107;114;128m"    # grigio  -> separatore
$cLabel = "$esc[38;2;180;186;196m"    # grigio chiaro -> etichette
$reset  = "$esc[0m"

# scala colori Context: verde -> giallo -> rosso (16-color brillanti)
$ctxScale = @("$esc[92m", "$esc[93m", "$esc[91m")
# scala colori Usage: azzurro -> arancione (truecolor)
$useScale = @("$esc[38;2;56;189;248m", "$esc[38;2;251;146;60m", "$esc[38;2;249;115;22m")

$full  = [string][char]0x2588   # blocco pieno
$empty = [string][char]0x2591   # blocco vuoto

# costruisce un segmento "Etichetta ████░░░░░░ NN%" con colore per soglia
# $scale = @(colore <50%, colore 50-80%, colore >80%)
function Get-Segment($label, $value, $scale) {
    $pct = $value
    if ($null -eq $pct) { $pct = 0 }
    $pct = [math]::Round([double]$pct)
    if ($pct -lt 0) { $pct = 0 }
    if ($pct -gt 100) { $pct = 100 }

    $filled = [int][math]::Round($pct / 10)
    $bar = ($full * $filled) + ($empty * (10 - $filled))

    if ($pct -gt 80)     { $cBar = $scale[2] }
    elseif ($pct -ge 50) { $cBar = $scale[1] }
    else                 { $cBar = $scale[0] }

    return "${cLabel}$label${reset} ${cBar}$bar ${pct}%${reset}"
}

# leggi lo stdin UNA sola volta
$data = [Console]::In.ReadToEnd() | ConvertFrom-Json
$m = $data.model.display_name

$ctx   = Get-Segment 'Context' $data.context_window.used_percentage         $ctxScale
$usage = Get-Segment 'Usage'   $data.rate_limits.five_hour.used_percentage  $useScale

# indicatore account GitHub connesso sulla MACCHINA (dato di macchina, non della cartella).
# Cache PER-SESSIONE: 'gh auth status' viene eseguito UNA sola volta per sessione di Claude
# Code e il risultato riusato a ogni refresh della barra. La cache e' un file indicizzato
# per session_id (stabile per sessione) dentro cache/, che il .gitignore esclude. Nessuna
# riesecuzione di gh a ogni tick della statusline.
$cGhOn  = "$esc[38;2;34;197;94m"    # verde  -> account connesso
$cGhOff = "$esc[38;2;107;114;128m"  # grigio -> nessun account
$dot    = [string][char]0x25CF      # pallino

# helper: " | ● testo" con colore del pallino e del testo
function Get-GhSeg($dotColor, $textColor, $text) {
    return " ${cSep}|${reset} ${dotColor}$dot${reset} ${textColor}$text${reset}"
}

$ghSeg = ''
try {
    # chiave stabile tra i refresh della stessa sessione; fallback prudente se assente
    $sid = $data.session_id
    if (-not $sid) { $sid = 'nosession' }
    $cacheDir  = Join-Path $HOME '.claude/cache'
    $cacheFile = Join-Path $cacheDir "gh-account.$sid.txt"

    if (Test-Path -LiteralPath $cacheFile) {
        # gia' interrogato in questa sessione: riuso il valore in cache
        $acct = Get-Content -LiteralPath $cacheFile -Raw
    } else {
        # prima volta nella sessione: interrogo gh UNA volta sola e salvo il risultato
        $acct = ''
        if (Get-Command gh -ErrorAction SilentlyContinue) {
            $out = & gh auth status 2>&1 | Out-String
            if ($out -match 'Logged in to\s+\S+\s+account\s+(\S+)') { $acct = $matches[1] }
        }
        if (-not (Test-Path -LiteralPath $cacheDir)) {
            New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
        }
        Set-Content -LiteralPath $cacheFile -Value $acct -NoNewline
    }

    $acct = "$acct".Trim()
    if ($acct) { $ghSeg = Get-GhSeg $cGhOn  $cLabel "GitHub: $acct" }
    else       { $ghSeg = Get-GhSeg $cGhOff $cLabel 'GitHub: off'   }
} catch {
    $ghSeg = Get-GhSeg $cGhOff $cLabel 'GitHub: off'
}

# saluto -- mappa esplicita email->nome, con fallback al comportamento attuale
# Per aggiungere un caso: inserisci una riga @{ Match = '<sottostringa email>'; Name = '<Nome>' }.
# Il match e' case-insensitive e la prima corrispondenza nell'ordine vince.
$nameMap = @(
    @{ Match = 'castinformaticait';  Name = 'Andrea' }
    @{ Match = 'solarinoalessandro'; Name = 'Alessandro' }
)
$name = $null   # dichiarato fuori dal try: deve sopravvivere a un'eccezione
try {
    # -AsHashtable: tollera la chiave a nome vuoto introdotta nel .claude.json
    # dall'auto-update (ConvertFrom-Json "stretto" vi lanciava un'eccezione).
    $cfg = Get-Content (Join-Path $HOME '.claude.json') -Raw | ConvertFrom-Json -AsHashtable
    $e = $cfg.oauthAccount.emailAddress
    if ($e) {
        foreach ($entry in $nameMap) {
            if ($e -like "*$($entry.Match)*") { $name = $entry.Name; break }
        }
        if (-not $name) {
            # fallback: parte prima della @, primo token su '.', iniziale maiuscola
            $n = (($e -split '@')[0] -split '\.')[0]
            if ($n) { $name = $n.Substring(0, 1).ToUpper() + $n.Substring(1) }
        }
    }
} catch {}
# fallback VISIBILE: se la lettura fallisce, l'email manca o il nome non si
# determina (incluso un futuro guasto che fa scattare il catch), mostra
# "Ciao, ?" invece di omettere il saluto -- cosi' il problema si nota subito.
if (-not $name) { $name = '?' }
$g = "${cCiao}Ciao, $name${reset} ${cSep}|${reset} "

# indicatore "build N": numero totale di commit del repo di config.
# Il repo coincide con la cartella che contiene QUESTO script ($PSScriptRoot): cosi'
# funziona ovunque il repo sia clonato (~/.claude, ~/willown-code, ...) senza path fissi.
# Il conteggio viene SEMPRE eseguito li', mai nella cwd in cui la statusline e' aperta.
# Solo commit locali: nessun contatto col remoto. Se git fallisce o non e' un repo,
# l'indicatore viene omesso senza rompere la barra.
$cBuild = "$esc[2;38;2;107;114;128m"   # grigio tenue (dim) -> defilato
$build = ''
try {
    $cfgRepo = $PSScriptRoot
    if ($cfgRepo -and (Get-Command git -ErrorAction SilentlyContinue) -and (Test-Path -LiteralPath $cfgRepo)) {
        if ((& git -C $cfgRepo rev-parse --is-inside-work-tree 2>$null) -eq 'true') {
            $count = & git -C $cfgRepo rev-list --count HEAD 2>$null
            if ($LASTEXITCODE -eq 0 -and $count -match '^\d+$') {
                $build = " ${cBuild}| build $count${reset}"
            }
        }
    }
} catch { $build = '' }

$sep = " ${cSep}|${reset} "
[Console]::Out.Write("$g${cModel}$m${reset}$sep$ctx$sep$usage$ghSeg$build")
