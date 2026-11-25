# Le halo de ta flèche sur la carte (Plus/Map/PinSets.lua) :
# écrit MyMapIsRich/Media/Textures/Glow.tga, 64 x 64.
# Un disque blanc qui s'efface doucement vers le bord (transparent au bord,
# le plus opaque au centre). Le jeu le teinte (SetVertexColor) et l'ajoute à
# ce qui est dessous (mode ADD) : il éclaire la carte autour de la flèche.
#   powershell -ExecutionPolicy Bypass -File tools\media\Glow.ps1
$size = 64
$out = Join-Path $PSScriptRoot "..\..\MyMapIsRich\Media\Textures\Glow.tga"

$pixels = New-Object byte[] ($size * $size * 4)
$c = ($size - 1) / 2
for ($y = 0; $y -lt $size; $y++) {
    for ($x = 0; $x -lt $size; $x++) {
        $dx = ($x - $c) / ($size / 2)
        $dy = ($y - $c) / ($size / 2)
        $r = [Math]::Sqrt($dx * $dx + $dy * $dy)
        # (une pente douce : rien au bord, plein au centre)
        $a = 0
        if ($r -lt 1) { $a = [Math]::Pow(1 - $r, 1.8) }
        $i = ($y * $size + $x) * 4
        $pixels[$i] = 255; $pixels[$i + 1] = 255; $pixels[$i + 2] = 255   # (B, G, R)
        $pixels[$i + 3] = [byte][Math]::Round($a * 255)
    }
}

# TGA 32 bits sans compression, origine en haut à gauche (comme Media/Arrow.tga)
$header = New-Object byte[] 18
$header[2] = 2
$header[12] = $size -band 0xFF; $header[13] = $size -shr 8
$header[14] = $size -band 0xFF; $header[15] = $size -shr 8
$header[16] = 32
$header[17] = 0x28
$stream = [System.IO.File]::Create($out)
$stream.Write($header, 0, 18)
$stream.Write($pixels, 0, $pixels.Length)
$stream.Close()
Write-Output "Glow.tga : $out"
