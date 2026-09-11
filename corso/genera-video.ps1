<#
.SYNOPSIS
    Registra il video del corso: la lavagna di corso/giornata.html, scena per
    scena, letta dalla voce italiana di Windows. Niente servizi esterni.

.DESCRIPTION
    Il testo sta tutto in giornata.html: le fasi (il blocco "lezioni") e la
    pronuncia delle parole inglesi (PRONUNCIA). Cambi la pagina, rilanci
    questo script, e il video la segue.

    Per ogni scena:
      1. Edge (o Chrome) senza finestra fotografa la lavagna a 1280x720
         (giornata.html?video=<scena>);
      2. la voce italiana di Windows (Microsoft Elsa) legge la didascalia in
         un file WAV;
      3. ffmpeg unisce immagine e voce.
    Alla fine ffmpeg mette in fila le scene in un MP4 solo.

    Serve: la voce italiana di Windows (Impostazioni > Ora e lingua > Voce),
    Microsoft Edge o Google Chrome, e ffmpeg nel PATH.

.PARAMETER Out
    Il file MP4 da scrivere (default: quaderno-esame.mp4 accanto alla pagina).

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File corso/genera-video.ps1
#>
param([string]$Out = (Join-Path $PSScriptRoot 'quaderno-esame.mp4'))

$ErrorActionPreference = 'Stop'
$html = Join-Path $PSScriptRoot 'giornata.html'
$page = [System.IO.File]::ReadAllText($html)

# --- Il testo, dalla pagina ----------------------------------------------------
$json = [regex]::Match($page, '(?s)<script id="lezioni" type="application/json">(.*?)</script>').Groups[1].Value
if (-not $json) { throw "Non trovo il blocco delle lezioni in $html." }
$lezioni = $json | ConvertFrom-Json
$block = [regex]::Match($page, '(?s)const PRONUNCIA = \[(.*?)\];').Groups[1].Value
$pronuncia = @([regex]::Matches($block, '\["([^"]+)", "([^"]+)"\]') | ForEach-Object { , @($_.Groups[1].Value, $_.Groups[2].Value) })

function Get-Speakable {
    param([string]$Text)
    foreach ($pair in $pronuncia) {
        $Text = [regex]::Replace($Text, '(^|[^\w-])' + [regex]::Escape($pair[0]) + '(?![\w-])', '${1}' + $pair[1])
    }
    return $Text
}

# --- Gli attrezzi -----------------------------------------------------------------
$browser = @(
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe"
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe"
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -First 1
if (-not $browser) { throw 'Serve Microsoft Edge o Google Chrome per fotografare la lavagna.' }
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) { throw 'Serve ffmpeg nel PATH (winget install ffmpeg, oppure choco install ffmpeg).' }

Add-Type -AssemblyName System.Speech
$synth = New-Object System.Speech.Synthesis.SpeechSynthesizer
$voice = $synth.GetInstalledVoices() | Where-Object { $_.Enabled -and $_.VoiceInfo.Culture.Name -eq 'it-IT' } | Select-Object -First 1
if (-not $voice) { throw 'Manca una voce italiana: Impostazioni > Ora e lingua > Voce > Aggiungi voci > Italiano.' }
$synth.SelectVoice($voice.VoiceInfo.Name)
$synth.Rate = 0

$work = Join-Path ([System.IO.Path]::GetTempPath()) ('corso-video-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $work | Out-Null
$url = 'file:///' + ($html -replace '\\', '/')

# --- Scena per scena ------------------------------------------------------------
$scenes = @()
foreach ($lezione in $lezioni) { foreach ($scena in $lezione.scene) { $scenes += [pscustomobject]@{ Titolo = $lezione.titolo; Dice = $scena.dice } } }

$list = New-Object System.Collections.Generic.List[string]
for ($i = 0; $i -lt $scenes.Count; $i++) {
    $name = 'scena-{0:D2}' -f $i
    $png = Join-Path $work "$name.png"
    $wav = Join-Path $work "$name.wav"
    $mp4 = Join-Path $work "$name.mp4"
    Write-Host ("  {0,2}/{1}  {2}" -f ($i + 1), $scenes.Count, $scenes[$i].Titolo) -ForegroundColor DarkGray

    # 1. La lavagna. Un profilo tutto suo: con Edge gia' aperto, senza, il
    # comando finirebbe nella finestra che hai davanti e non fotograferebbe
    # niente. virtual-time-budget: il tempo per caricare i caratteri.
    # $($url) e non $url: in PowerShell 5.1 il ? fa parte del nome di una
    # variabile, e "$url?video" diventerebbe una variabile vuota.
    $target = "$($url)?video=$i"
    cmd /c "`"$browser`" --headless=new --disable-gpu --hide-scrollbars --user-data-dir=`"$work\profilo`" --window-size=1280,720 --virtual-time-budget=6000 --screenshot=`"$png`" `"$target`" >NUL 2>&1"
    if (-not (Test-Path $png)) { throw "Il browser non ha fotografato la scena $i." }

    # 2. La voce.
    $synth.SetOutputToWaveFile($wav)
    $synth.Speak((Get-Speakable $scenes[$i].Dice))
    $synth.SetOutputToNull()

    # 3. Immagine ferma + voce, con mezzo secondo di respiro in fondo.
    cmd /c "ffmpeg -y -v error -loop 1 -framerate 10 -i `"$png`" -i `"$wav`" -af apad=pad_dur=0.7 -c:v libx264 -tune stillimage -preset veryfast -pix_fmt yuv420p -c:a aac -b:a 128k -ar 48000 -shortest `"$mp4`" 2>&1"
    if ($LASTEXITCODE -ne 0) { throw "ffmpeg non ha montato la scena $i." }
    $list.Add("file '" + ($mp4 -replace '\\', '/') + "'")
}
$synth.Dispose()

# --- Tutte in fila --------------------------------------------------------------
$listFile = Join-Path $work 'scene.txt'
[System.IO.File]::WriteAllLines($listFile, $list)
cmd /c "ffmpeg -y -v error -f concat -safe 0 -i `"$listFile`" -c copy -movflags +faststart `"$Out`" 2>&1"
if ($LASTEXITCODE -ne 0) { throw 'ffmpeg non ha unito le scene.' }
Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue

$seconds = [double](cmd /c "ffprobe -v error -show_entries format=duration -of csv=p=0 `"$Out`"")
Write-Host ''
Write-Host ("Video pronto: {0}  ({1:N0} min {2:N0} s, {3:N1} MB)" -f $Out, [math]::Floor($seconds / 60), ($seconds % 60), ((Get-Item $Out).Length / 1MB)) -ForegroundColor Green
