# La flèche GPS du panneau de trajet (Plus/UI/RouteHud.lua) :
# écrit MyMapIsRich/Media/Arrow.tga, 128 x 128, pointe vers le haut.
# Une flèche en deux facettes (blanche à gauche, grise à droite, pour le
# relief), un contour noir et un halo sombre tout autour (le même dans toutes
# les directions, puisque la flèche tourne). Le jeu la teinte
# (SetVertexColor) : le blanc prend la couleur, le noir reste noir.
#   powershell -ExecutionPolicy Bypass -File tools\media\Arrow.ps1 [aperçu.png]
param([string]$Preview)

Add-Type -AssemblyName System.Drawing

$size = 128
$out = Join-Path $PSScriptRoot "..\..\MyMapIsRich\Media\Arrow.tga"

$bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
$g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))

function P($x, $y) { New-Object System.Drawing.PointF($x, $y) }

# (tout reste dans le cercle inscrit : la rotation ne rogne rien)
$tip   = P 64 14
$right = P 101 102
$notch = P 64 82
$left  = P 27 102
$shape = [System.Drawing.PointF[]]@($tip, $right, $notch, $left)

function Outline($width, $alpha) {
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($alpha, 0, 0, 0), $width)
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $g.DrawPolygon($pen, $shape)
    $pen.Dispose()
}

# (le halo, du plus large au plus serré)
Outline 18 22
Outline 14 34
Outline 10 52

# (les deux facettes)
$light = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255, 255))
$dark  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 178, 178, 178))
$g.FillPolygon($light, [System.Drawing.PointF[]]@($tip, $notch, $left))
$g.FillPolygon($dark,  [System.Drawing.PointF[]]@($tip, $right, $notch))

# (le contour)
Outline 5 235
$g.Dispose()

# TGA 32 bits sans compression, origine en haut à gauche (comme Media/Icon.tga)
$rect = New-Object System.Drawing.Rectangle(0, 0, $size, $size)
$data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $bmp.PixelFormat)
$pixels = New-Object byte[] ($size * $size * 4)
[System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $pixels, 0, $pixels.Length)
$bmp.UnlockBits($data)

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
Write-Output "Arrow.tga : $out"

# (l'aperçu : la flèche dorée sur le fond du panneau)
if ($Preview) {
    $view = New-Object System.Drawing.Bitmap(256, 128)
    $v = [System.Drawing.Graphics]::FromImage($view)
    $v.Clear([System.Drawing.Color]::FromArgb(255, 28, 22, 17))
    $gold = New-Object System.Drawing.Imaging.ColorMatrix
    $gold.Matrix00 = 1; $gold.Matrix11 = 0.82; $gold.Matrix22 = 0; $gold.Matrix33 = 1; $gold.Matrix44 = 1
    $attr = New-Object System.Drawing.Imaging.ImageAttributes
    $attr.SetColorMatrix($gold)
    $v.DrawImage($bmp, $rect, 0, 0, $size, $size, [System.Drawing.GraphicsUnit]::Pixel, $attr)
    $v.TranslateTransform(192, 64); $v.RotateTransform(40); $v.TranslateTransform(-64, -64)
    $green = New-Object System.Drawing.Imaging.ColorMatrix
    $green.Matrix00 = 0.35; $green.Matrix11 = 1; $green.Matrix22 = 0.35; $green.Matrix33 = 1; $green.Matrix44 = 1
    $attr2 = New-Object System.Drawing.Imaging.ImageAttributes
    $attr2.SetColorMatrix($green)
    $v.DrawImage($bmp, $rect, 0, 0, $size, $size, [System.Drawing.GraphicsUnit]::Pixel, $attr2)
    $v.Dispose()
    $view.Save($Preview, [System.Drawing.Imaging.ImageFormat]::Png)
    $view.Dispose()
}
$bmp.Dispose()
