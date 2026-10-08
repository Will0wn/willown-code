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

# effort del modello (low/medium/high/xhigh/max) accanto al nome; omesso se assente
$cEffort = "$esc[38;2;253;224;71m"   # giallo chiaro -> effort
if ($data.effort.level) { $m += " ${reset}${cSep}·${reset} ${cEffort}$($data.effort.level)" }

$ctx   = Get-Segment 'Context' $data.context_window.used_percentage         $ctxScale
$usage = Get-Segment 'Usage'   $data.rate_limits.five_hour.used_percentage  $useScale
# orario di reset della finestra di 5 ore, in ora locale
$resetAt = $data.rate_limits.five_hour.resets_at
if ($resetAt) {
    $when = [DateTimeOffset]::FromUnixTimeSeconds([long]$resetAt).LocalDateTime
    $left = $when - (Get-Date)
    $in = if ($left.TotalMinutes -le 0) { 'now' } elseif ($left.TotalHours -ge 1) { '{0}h {1:00}m' -f [int][math]::Floor($left.TotalHours), $left.Minutes } else { '{0}m' -f [int][math]::Ceiling($left.TotalMinutes) }
    $cDim = "$esc[2;38;2;180;186;196m"
    $usage += " ${cSep}·${reset} ${cLabel}$([char]0x21BB) $($when.ToString('HH:mm'))${reset} ${cDim}in $in${reset}"
}

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
    # prima scelta: il nome visualizzato dell'account Claude
    $dn = "$($cfg.oauthAccount.displayName)".Trim()
    if ($dn) { $name = ($dn -split '\s+')[0] }
    $e = $cfg.oauthAccount.emailAddress
    if ($e -and -not $name) {
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

# diavoletto 😈 in pixel art alto 4 righe: ogni cella e' un mezzo blocco con due colori
# (sopra = primo piano, sotto = sfondo), quindi 8 righe di pixel.
# P = viola, . = trasparente (occhi e bocca sono "buchi")
$px = @{ 'P' = '168;85;247' }
$art = @(
    'P..........P'
    'PP.PPPPPP.PP'
    '.PPPPPPPPPP.'
    'PP..PPPP..PP'
    'PPP..PP..PPP'
    'PPPPPPPPPPPP'
    'PP.PPPPPP.PP'
    '.PP......PP.'
)
# animazione "tamagotchi": con refreshInterval la barra gira ogni secondo e il fotogramma
# dipende dal secondo corrente -> ondeggia di una colonna e ogni tanto sbatte le palpebre
$tick = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() % 6
if ($tick -eq 3) { $art[3] = 'PPPPPPPPPPPP'; $art[4] = 'PP..PPPP..PP' }   # occhi chiusi
$shift = $tick -in 1, 4
$art = $art | ForEach-Object { if ($shift) { ".$_" } else { "$_." } }
$logo = for ($r = 0; $r -lt $art.Count; $r += 2) {
    $line = ''
    for ($c = 0; $c -lt $art[$r].Length; $c++) {
        $t = $px["$($art[$r][$c])"]; $b = $px["$($art[$r + 1][$c])"]
        if ($t -and $b) { $line += "$esc[38;2;${t}m$esc[48;2;${b}m$([char]0x2580)$reset" }
        elseif ($t)     { $line += "$esc[38;2;${t}m$([char]0x2580)$reset" }
        elseif ($b)     { $line += "$esc[38;2;${b}m$([char]0x2584)$reset" }
        else            { $line += ' ' }
    }
    # il reset iniziale impedisce che gli spazi in testa vengano tolti (sposterebbe il testo)
    "$reset$line "
}
[Console]::Out.Write("$($logo[0])$g${cModel}$m${reset}$sep$ctx$sep$usage$build")

# seconda riga: nome della cartella di lavoro
$cDir = "$esc[38;2;96;165;250m"   # blu -> cartella
$dir = $data.workspace.current_dir
if (-not $dir) { $dir = $data.cwd }
$folder = if ($dir) { Split-Path -Leaf $dir } else { '?' }
[Console]::Out.Write("`n$($logo[1])${cLabel}Folder${reset} ${cDir}$folder${reset}$ghSeg")

# terza riga: MCP connessi. 'claude mcp list' impiega ~8s, quindi gira in background
# una volta per sessione e scrive in cache; finche' la cache non c'e' mostra "...".
$cMcp = "$esc[38;2;52;211;153m"   # verde acqua -> MCP
$mcpText = '...'
try {
    $sid = $data.session_id; if (-not $sid) { $sid = 'nosession' }
    $cacheDir = Join-Path $HOME '.claude/cache'
    $mcpFile  = Join-Path $cacheDir "mcp.$sid.txt"
    $mcpLock  = "$mcpFile.lock"
    if (Test-Path -LiteralPath $mcpFile) {
        # nomi visualizzati: nome server -> etichetta
        $mcpNames = @{}
        $mcpText = ((Get-Content -LiteralPath $mcpFile -Raw).Trim() -split ', ' | Where-Object { $_ } |
            ForEach-Object { if ($mcpNames.ContainsKey($_)) { $mcpNames[$_] } else { $_ } }) -join ', '
        if (-not $mcpText) { $mcpText = 'none' }
    } elseif (-not (Test-Path -LiteralPath $mcpLock) -or
              ((Get-Date) - (Get-Item -LiteralPath $mcpLock).LastWriteTime).TotalSeconds -gt 60) {
        if (-not (Test-Path -LiteralPath $cacheDir)) { New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null }
        New-Item -ItemType File -Path $mcpLock -Force | Out-Null
        $job = @"
`$names = claude mcp list 2>`$null | Where-Object { `$_ -match 'Connected' } | ForEach-Object { ((`$_ -split ': ', 2)[0]) -replace '^claude\.ai ', '' }
Set-Content -LiteralPath '$mcpFile' -Value (`$names -join ', ') -NoNewline
Remove-Item -LiteralPath '$mcpLock' -Force
"@
        $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($job))
        # avvio via WMI: il processo nasce fuori dal job di Claude Code, che altrimenti
        # lo termina insieme alla statusline prima che finisca
        # WMI non cerca nel PATH: serve il percorso completo di pwsh
        $cmdLine = "`"$(Join-Path $PSHOME 'pwsh.exe')`" -NoProfile -WindowStyle Hidden -EncodedCommand $enc"
        Invoke-CimMethod -ClassName Win32_Process -MethodName Create -Arguments @{ CommandLine = $cmdLine } | Out-Null
    }
} catch { $mcpText = '?' }
[Console]::Out.Write("`n$($logo[2])${cLabel}MCP${reset} ${cMcp}$mcpText${reset}")

# quarta riga: per ora solo la base del diavoletto
[Console]::Out.Write("`n$($logo[3])")
