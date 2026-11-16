$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Runtime.WindowsRuntime
$synthType = [Windows.Media.SpeechSynthesis.SpeechSynthesizer, Windows.Media.SpeechSynthesis, ContentType=WindowsRuntime]
$streamType = [Windows.Media.SpeechSynthesis.SpeechSynthesisStream, Windows.Media.SpeechSynthesis, ContentType=WindowsRuntime]
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1
$awaitStream = $asTask.MakeGenericMethod($streamType)
$voiceDirectory = '2D/assets/campaign/voice'
New-Item -ItemType Directory -Path $voiceDirectory -Force | Out-Null
$rosterText = [System.IO.File]::ReadAllText((Resolve-Path '2D/duel_roster.gd'))

function Read-RosterSection([string] $name, [string] $nextConstant) {
    $rows = [regex]::Match($rosterText, "(?s)const $name := \[(.*?)\]\s*const $nextConstant")
    if (!$rows.Success) { throw "Missing roster section $name" }
    return $rows.Groups[1].Value
}

$labels = @([regex]::Matches((Read-RosterSection 'SKILL_NAMES' 'SKILL_GAGS'), '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$superCalls = @([regex]::Matches((Read-RosterSection 'SUPER_CALLS' 'SUPER_GAGS'), '"([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
$characters = @('liu', 'gu', 'pei', 'shi', 'lu', 'ruan', 'wen', 'fang', 'hong')
$voices = @('Yating', 'Zhiwei', 'Zhiwei', 'Zhiwei', 'Zhiwei', 'Hanhan', 'Yating', 'Zhiwei', 'Zhiwei')
$pitches = @(1.04, 1.02, 1.09, 0.84, 1.16, 1.01, 0.93, 0.94, 0.77)
if ($labels.Count -ne 27 -or $superCalls.Count -ne 9) {
    throw 'Unexpected voice line count'
}

$source = [Collections.Generic.List[string]]::new()
$source.Add('extends RefCounted')
$source.Add('')
$source.Add('const CLIPS := [')
for ($character = 0; $character -lt $characters.Count; $character++) {
    $synth = $synthType::new()
    try {
        $voice = $synthType::AllVoices | Where-Object { $_.Language -eq 'zh-TW' -and $_.DisplayName.EndsWith($voices[$character]) } | Select-Object -First 1
        if (!$voice) { throw "Taiwan Mandarin voice missing: $($voices[$character])" }
        $synth.Voice = $voice
        $synth.Options.AudioPitch = $pitches[$character]
        $lines = for ($slot = 0; $slot -lt 3; $slot++) {
            $index = $character * 3 + $slot
            $labels[$index]
        }
        $lines = @($lines) + @($superCalls[$character])
        $row = for ($slot = 0; $slot -lt $lines.Count; $slot++) {
            $filename = "$($characters[$character])-$slot.wav"
            $synth.Options.SpeakingRate = if ($slot -eq 3) { 1.22 } else { 1.38 }
            $task = $awaitStream.Invoke($null, @($synth.SynthesizeTextToStreamAsync($lines[$slot])))
            $speech = $task.GetAwaiter().GetResult()
            $readable = [System.IO.WindowsRuntimeStreamExtensions]::AsStreamForRead($speech)
            $output = [IO.File]::Create((Join-Path (Resolve-Path $voiceDirectory) $filename))
            try { $readable.CopyTo($output) } finally { $output.Dispose(); $readable.Dispose() }
            'preload("res://' + $voiceDirectory + '/' + $filename + '")'
        }
        $source.Add("`t[" + ($row -join ', ') + '],')
    } finally {
        $synth.Dispose()
    }
}
$source.Add(']')
[IO.File]::WriteAllLines((Join-Path (Get-Location) '2D/duel_voice.gd'), $source, [Text.UTF8Encoding]::new($false))
Write-Output 'Generated 36 zh-TW Mandarin move calls.'
