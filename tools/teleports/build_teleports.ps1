# Les téléportations de classe pour les itinéraires (MyMapIsRich/Plus/Data/Teleports.lua) : le sort,
# où il pose sur les continents de la carte, et la rune qu'il demande.
# Source : Shortest Path Forever de cjber (GPL-3.0-or-later) : Data/Teleports.lua (les sorts du jeu et
# leurs destinations, d'après la base de cMaNGOS). Ceux qui posent là où tu as lié ta pierre de foyer
# (la pierre, Rappel astral) sont laissés de côté : les itinéraires ne les prennent pas.
#   powershell -ExecutionPolicy Bypass -File tools\teleports\build_teleports.ps1 [dossier de ShortestPathForever]
param([string]$Spf = "K:\World of Warcraft\_forever_\Interface\AddOns\ShortestPathForever")

$ErrorActionPreference = "Stop"
$out = Join-Path $PSScriptRoot "..\..\MyMapIsRich\Plus\Data\Teleports.lua"
$continents = @{ "0" = $true; "1" = $true }

function Read-Text([string]$path) {
    return [IO.File]::ReadAllText((Join-Path $Spf $path), [Text.Encoding]::UTF8)
}

$version = "?"
$toc = Read-Text "ShortestPathForever.toc"
$m = [regex]::Match($toc, "(?m)^## Version: (.+)$")
if ($m.Success) { $version = $m.Groups[1].Value.Trim() }

# Chaque entrée : son commentaire (le nom du sort), puis { spell = ..., to = { map, x, y, z }, cast, reagents }
$rows = New-Object System.Collections.Generic.List[string]
$text = Read-Text "Data\Teleports.lua"
# (une entrée : de son commentaire au commentaire suivant, ou à la fin de la table)
foreach ($t in [regex]::Matches($text, '(?ms)^\t--\s*([^\r\n]+?)\s*\r?\n(.*?)(?=^\t--|^\})')) {
    $name, $body = $t.Groups[1].Value, $t.Groups[2].Value
    $spell = [regex]::Match($body, 'spell = (\d+)')
    $to = [regex]::Match($body, 'to = \{ map = (\d+), x = (-?[\d.]+), y = (-?[\d.]+)')
    if (-not ($spell.Success -and $to.Success)) { continue }
    if ($body -match 'bind = true') { continue }
    if (-not $continents.ContainsKey($to.Groups[1].Value)) { continue }
    $reagent = [regex]::Match($body, 'reagents = \{ \[(\d+)\] = \d+ \}')
    $cast = [regex]::Match($body, 'cast = (\d+)')
    $secs = if ($cast.Success) { [int]$cast.Groups[1].Value / 1000 } else { 10 }
    $r = if ($reagent.Success) { ", reagent = {0}" -f $reagent.Groups[1].Value } else { "" }
    $rows.Add(("`t{{ spell = {0}, cont = {1}, x = {2}, y = {3}, cast = {4}{5} }}, -- {6}" -f $spell.Groups[1].Value, $to.Groups[1].Value, $to.Groups[2].Value, $to.Groups[3].Value, $secs, $r, $name))
}

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("-- Généré par tools/teleports/build_teleports.ps1 : ne pas modifier à la main.")
$lines.Add("-- Les téléportations de classe que les itinéraires peuvent prendre (Travel/Planner.lua).")
$lines.Add("-- Source : Shortest Path Forever v$version de cjber (https://github.com/cjber/shortest-path-forever),")
$lines.Add("-- Data/Teleports.lua. Données dérivées, sous licence GPL-3.0-or-later (voir LICENSE).")
$lines.Add("--   { spell, cont, x, y (où le sort pose, en yards du monde), cast (s), reagent (l'objet qu'il demande) }")
$lines.Add("-- x vers le nord, y vers l'ouest (UnitPosition).")
$lines.Add("local _, root = ...")
$lines.Add("local ns = root.Plus")
$lines.Add("")
$lines.Add("ns.TeleportData = {")
foreach ($l in $rows) { $lines.Add($l) }
$lines.Add("}")

$out = [IO.Path]::GetFullPath($out)
[IO.File]::WriteAllText($out, (($lines -join "`n") + "`n"), (New-Object Text.UTF8Encoding($false)))
Write-Host ("{0} téléportations -> {1}" -f $rows.Count, $out)
