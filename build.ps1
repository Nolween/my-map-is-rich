# Paquet de publication : ..\Releases\MyMapIsRich\MyMapIsRich-<version>.zip
#   .\build.ps1
# La version vient du .toc (## Version). Le dossier MyMapIsRich est mis
# dans le zip tel quel, avec le journal des versions.
# Les chemins du zip sont écrits avec des « / » : Compress-Archive de
# PowerShell 5.1 écrit des « \ », que certains gestionnaires d'addons
# lisent mal.
$ErrorActionPreference = 'Stop'

$root = $PSScriptRoot
$addon = 'MyMapIsRich'
$source = Join-Path $root $addon
$toc = Join-Path $source "$addon.toc"

# (fichiers gardés hors du paquet, chemins relatifs au dossier de l'addon)
$exclude = @()

$versionLine = Select-String -Path $toc -Pattern '^## Version:\s*(.+)$' | Select-Object -First 1
if (-not $versionLine) { throw "Pas de ligne '## Version' dans $toc" }
$version = $versionLine.Matches[0].Groups[1].Value.Trim()

$dist = Join-Path (Join-Path (Split-Path $root -Parent) 'Releases') $addon
New-Item -ItemType Directory -Force $dist | Out-Null
$zipPath = Join-Path $dist "$addon-$version.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath -Force -Confirm:$false }

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$prefix = $source.TrimEnd('\') + '\'
$files = Get-ChildItem -Path $source -Recurse -File | Where-Object {
    $rel = $_.FullName.Substring($prefix.Length) -replace '\\', '/'
    -not ($exclude -contains $rel)
}

$count = 0
$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($file in $files) {
        $rel = $file.FullName.Substring($prefix.Length) -replace '\\', '/'
        $entry = "$addon/$rel"
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $file.FullName, $entry, [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        $count++
    }
    # (le journal des versions, à la racine du dépôt, va dans le dossier de l'addon)
    $changelog = Join-Path $root 'CHANGELOG.md'
    if (Test-Path $changelog) {
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $changelog, "$addon/CHANGELOG.md", [System.IO.Compression.CompressionLevel]::Optimal) | Out-Null
        $count++
    }
} finally {
    $zip.Dispose()
}

Write-Host "$zipPath : $count fichiers (version $version)"
