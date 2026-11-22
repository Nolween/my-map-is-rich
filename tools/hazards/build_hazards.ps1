# Les villes de l'autre faction pour les itinéraires (MyMapIsRich/Plus/Data/Hazards.lua) :
# le terrain de chaque ville autour d'un maître de vol, et celui des capitales.
# Source : Shortest Path Forever de cjber (GPL-3.0-or-later) :
#   Data/TownAreas.lua : par maître de vol, les morceaux de terrain (33,3 yards) que le
#     client appelle du nom de la ville ;
#   Data/Zones.lua : les capitales et leur faction ;
#   Data/ZoneCells.lua : la carte de chaque carré de 64 yards des continents.
# Le jeu (Plus/Travel/Nav.lua) en tire les villes hostiles selon ta faction.
#   powershell -ExecutionPolicy Bypass -File tools\hazards\build_hazards.ps1 [dossier de ShortestPathForever]
param([string]$Spf = "K:\World of Warcraft\_forever_\Interface\AddOns\ShortestPathForever")

$ErrorActionPreference = "Stop"
$out = Join-Path $PSScriptRoot "..\..\MyMapIsRich\Plus\Data\Hazards.lua"
$continents = @{ "0" = $true; "1" = $true }

function Read-Text([string]$path) {
    return [IO.File]::ReadAllText((Join-Path $Spf $path), [Text.Encoding]::UTF8)
}

$version = "?"
$toc = Read-Text "ShortestPathForever.toc"
$m = [regex]::Match($toc, "(?m)^## Version: (.+)$")
if ($m.Success) { $version = $m.Groups[1].Value.Trim() }

# Les villes : une ligne par maître de vol
$towns = New-Object System.Collections.Generic.List[string]
$townText = Read-Text "Data\TownAreas.lua"
$pattern = '(?m)^\s*\[(\d+)\] = \{ area = \d+, map = (\d+), i0 = (-?\d+), j0 = (-?\d+), w = (\d+), h = (\d+), cells = "([A-Za-z0-9+/]*)" \},\s*--\s*(.*?)\s*$'
foreach ($t in [regex]::Matches($townText, $pattern)) {
    $g = $t.Groups
    if (-not $continents.ContainsKey($g[2].Value)) { continue }
    $name = ($g[8].Value -replace '\s*\(\d+ chunks\)$', '')
    $towns.Add(("`t`t[{0}] = {{ {1}, {2}, {3}, {4}, {5}, ""{6}"" }}, -- {7}" -f $g[1].Value, $g[2].Value, $g[3].Value, $g[4].Value, $g[5].Value, $g[6].Value, $g[7].Value, $name))
}

# Les capitales : leur faction et leur continent (Zones.lua)
$capitals = [ordered]@{}
$zonesText = Read-Text "Data\Zones.lua"
foreach ($z in [regex]::Matches($zonesText, '\[(\d+)\] = \{\s*city = "(\w+)",.*?map = (\d+)', "Singleline")) {
    $capitals[$z.Groups[1].Value] = @{ side = $z.Groups[2].Value; cont = $z.Groups[3].Value; runs = New-Object System.Collections.Generic.List[string] }
}

# Leurs carrés de 64 yards (ZoneCells.lua) : pour chaque colonne, des suites de « zone nombre » depuis j0
$cellsText = Read-Text "Data\ZoneCells.lua"
foreach ($c in [regex]::Matches($cellsText, '\[(\d+)\] = \{ i0 = (-?\d+), j0 = (-?\d+), columns = \{(.*?)\}', "Singleline")) {
    $cont = $c.Groups[1].Value
    if (-not $continents.ContainsKey($cont)) { continue }
    $i = [int]$c.Groups[2].Value
    $j0 = [int]$c.Groups[3].Value
    foreach ($col in [regex]::Matches($c.Groups[4].Value, '"([^"]*)"')) {
        $nums = @($col.Groups[1].Value -split '\s+' | Where-Object { $_ -ne "" })
        $at = $j0
        for ($k = 0; $k + 1 -lt $nums.Count; $k += 2) {
            $zone, $count = $nums[$k], [int]$nums[$k + 1]
            $cap = $capitals[$zone]
            if ($cap -and $cap.cont -eq $cont) { $cap.runs.Add(("{0} {1} {2}" -f $i, $at, $count)) }
            $at += $count
        }
        $i++
    }
}

$names = @{ "1453" = "Stormwind"; "1454" = "Orgrimmar"; "1455" = "Ironforge"; "1456" = "Thunder Bluff"; "1457" = "Darnassus"; "1458" = "Undercity" }
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("-- Généré par tools/hazards/build_hazards.ps1 : ne pas modifier à la main.")
$lines.Add("-- Les villes de l'autre faction, que les chemins à pied contournent (Travel/Nav.lua).")
$lines.Add("-- Source : Shortest Path Forever v$version de cjber (https://github.com/cjber/shortest-path-forever),")
$lines.Add("-- Data/TownAreas.lua, Data/Zones.lua et Data/ZoneCells.lua (lus dans les données du client). Données")
$lines.Add("-- dérivées, sous licence GPL-3.0-or-later (voir LICENSE).")
$lines.Add("--   towns[maître de vol] = { continent, i0, j0, w, h, cases } : le terrain que le client appelle du nom")
$lines.Add("--     de la ville, en morceaux de 100/3 yards (le morceau (i, j) couvre x dans [i, i + 1), y dans")
$lines.Add("--     [j, j + 1) fois 100/3) ; cases : w x h bits, x d'abord depuis (i0, j0), six bits par symbole")
$lines.Add("--     base64 (A-Za-z0-9+/), le plus fort d'abord.")
$lines.Add("--   capitals[carte] = { faction, continent, ""i j n ..."" } : les carrés de 64 yards de la capitale,")
$lines.Add("--     n carrés de la colonne i (x / 64) à partir de la ligne j (y / 64).")
$lines.Add("-- x vers le nord, y vers l'ouest (UnitPosition), en yards du monde.")
$lines.Add("local _, root = ...")
$lines.Add("local ns = root.Plus")
$lines.Add("")
$lines.Add("ns.HazardData = {")
$lines.Add("`ttowns = {")
foreach ($l in $towns) { $lines.Add($l) }
$lines.Add("`t},")
$lines.Add("`tcapitals = {")
foreach ($id in $capitals.Keys) {
    $cap = $capitals[$id]
    if ($cap.runs.Count -eq 0) { continue }
    $lines.Add(("`t`t[{0}] = {{ ""{1}"", {2}, ""{3}"" }}, -- {4}" -f $id, $cap.side, $cap.cont, ($cap.runs -join " "), $names[$id]))
}
$lines.Add("`t},")
$lines.Add("}")

$text = ($lines -join "`n") + "`n"
[IO.File]::WriteAllText([IO.Path]::GetFullPath($out), $text, (New-Object Text.UTF8Encoding($false)))
Write-Host ("{0} villes, {1} capitales -> {2}" -f $towns.Count, $capitals.Count, $out)
