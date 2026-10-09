# Alle Posen aus blender/*.blend fürs Spiel exportieren (-> assets/poses/NAME.json).
# Aufruf im Projektordner (PowerShell):  .\tools\export_poses.ps1
# Die Vorlagen (*_vorlage.*) werden übersprungen.
$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
$root = Split-Path -Parent $PSScriptRoot
Get-ChildItem (Join-Path $root "blender") -Filter *.blend | ForEach-Object {
    $out = Join-Path $root ("assets\poses\" + $_.BaseName + ".json")
    & $blender -b $_.FullName --python (Join-Path $root "tools\export_pose.py") -- $out 2>&1 |
        Select-String "POSE EXPORT|Error|Traceback"
}
