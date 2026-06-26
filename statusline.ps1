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

# indicatore remoto git (solo config locale, nessun contatto col server)
$cDotGreen = "$esc[38;2;34;197;94m"    # verde  -> con remoto
$cDotGrey  = "$esc[38;2;107;114;128m"  # grigio -> solo locale (no remoto / no repo)
$cDotRed   = "$esc[38;2;239;68;68m"    # rosso  -> errore reale
$dot   = [string][char]0x25CF          # pallino
$arrow = [string][char]0x2192          # freccia

# helper: "| ● testo" con colore del pallino e del testo
function Get-GitSeg($dotColor, $textColor, $text) {
    return " ${cSep}|${reset} ${dotColor}$dot${reset} ${textColor}$text${reset}"
}

$git = ''
try {
    $dir = $data.workspace.current_dir
    if (-not $dir) { $dir = $data.cwd }

    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        # git assente: comunque lavoro locale, ma segnalo il perche'
        $git = Get-GitSeg $cDotGrey $cLabel 'locale (git non installato)'
    }
    elseif (-not $dir -or -not (Test-Path -LiteralPath $dir)) {
        # vera anomalia: la cartella indicata non esiste
        $git = Get-GitSeg $cDotRed $cDotRed 'cartella assente'
    }
    else {
        $isRepo = & git -C $dir rev-parse --is-inside-work-tree 2>$null
        if ($isRepo -ne 'true') {
            # git c'e' ma qui non e' un repo
            $git = Get-GitSeg $cDotGrey $cLabel 'locale (git installato ma non utilizzato)'
        }
        else {
            $url = & git -C $dir remote get-url origin 2>$null
            if ($url) {
                $repo = ($url -replace '\.git/?$', '') -replace '^.*[:/]([^/]+/[^/]+)$', '$1'
                $git = Get-GitSeg $cDotGreen $cLabel "$arrow $repo"
            } else {
                # repo git ma senza remoto configurato
                $git = Get-GitSeg $cDotGrey $cLabel 'locale (repo senza remoto)'
            }
        }
    }
} catch {
    $git = Get-GitSeg $cDotRed $cDotRed 'git errore'
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
[Console]::Out.Write("$g${cModel}$m${reset}$sep$ctx$sep$usage$git$build")
