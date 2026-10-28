# Variants de story d'Instagram (1080x1920): "blur" (foto sencera sobre fons desenfocat) i "split" (foto a dalt, text gran a sota).
param(
    [Parameter(Mandatory)] [string] $Photo,
    [Parameter(Mandatory)] [string] $Title,
    [Parameter(Mandatory)] [string] $Date,
    [Parameter(Mandatory)] [string] $OutDir,
    [Parameter(Mandatory)] [string] $BebasFont,
    [string] $Kicker = 'NOVA ENTRADA AL BLOG',
    [string] $Section = 'SURF AL CARIB I MÉS ENLLÀ'
)
Add-Type -AssemblyName System.Drawing
$W = 1080; $H = 1920
$bgC = [System.Drawing.ColorTranslator]::FromHtml('#12181b')
$turq = [System.Drawing.ColorTranslator]::FromHtml('#4fc1cf')
$text = [System.Drawing.ColorTranslator]::FromHtml('#e8e4dc')
$muted = [System.Drawing.ColorTranslator]::FromHtml('#9aa6ab')
$pfc = New-Object System.Drawing.Text.PrivateFontCollection; $pfc.AddFontFile($BebasFont); $bebas = $pfc.Families[0]
$tf = [System.Drawing.StringFormat]::GenericTypographic.Clone()
$tf.FormatFlags = $tf.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces

function Load([string] $p) {
    $img = [System.Drawing.Image]::FromFile($p)
    if ($img.PropertyIdList -contains 0x0112) {
        switch ([int]$img.GetPropertyItem(0x0112).Value[0]) { 3 { $img.RotateFlip('Rotate180FlipNone') } 6 { $img.RotateFlip('Rotate90FlipNone') } 8 { $img.RotateFlip('Rotate270FlipNone') } }
    }
    $img
}
function New-Canvas { $b = New-Object System.Drawing.Bitmap $W, $H; $g = [System.Drawing.Graphics]::FromImage($b); $g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'; $g.TextRenderingHint = 'AntiAliasGridFit'; $g.PixelOffsetMode = 'HighQuality'; $g.Clear($bgC); @($b, $g) }
function Spaced($g, [string]$s, $font, $color, [float]$x, [float]$y, [float]$sp, [string]$align = 'center') {
    $br = New-Object System.Drawing.SolidBrush $color
    $ws = $s.ToCharArray() | ForEach-Object { $g.MeasureString([string]$_, $font, 2000, $tf).Width }
    $tot = ($ws | Measure-Object -Sum).Sum + $sp * ($s.Length - 1)
    if ($align -eq 'center') { $x = $x - $tot / 2 }
    for ($i = 0; $i -lt $s.Length; $i++) { $g.DrawString([string]$s[$i], $font, $br, $x, $y, $tf); $x += $ws[$i] + $sp }
}
function Brand($g, [float]$y, [float]$size) {
    $f = New-Object System.Drawing.Font($bebas, [single]$size, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
    $w1 = $g.MeasureString('MIKI ', $f, 4000, $tf).Width; $w2 = $g.MeasureString('ROSINYOL', $f, 4000, $tf).Width
    $x = ($W - $w1 - $w2) / 2
    $g.DrawString('MIKI ', $f, (New-Object System.Drawing.SolidBrush $text), $x, $y, $tf)
    $g.DrawString('ROSINYOL', $f, (New-Object System.Drawing.SolidBrush $turq), $x + $w1, $y, $tf)
}
function Save($b, [string]$name) {
    $jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
    $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]92)
    $out = Join-Path $OutDir $name; $b.Save($out, $jpeg, $ep); $out
}
$fKick = New-Object System.Drawing.Font('Segoe UI Semibold', [single]30, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$fDate = New-Object System.Drawing.Font('Segoe UI Semibold', [single]32, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)

# --- Variant BLUR: la mateixa foto, desenfocada, omple el fons; la foto sencera al mig
$img = Load $Photo
$c = New-Canvas; $b = $c[0]; $g = $c[1]
$small = New-Object System.Drawing.Bitmap 27, 48
$gs = [System.Drawing.Graphics]::FromImage($small); $gs.InterpolationMode = 'HighQualityBilinear'
$sc = [Math]::Max(27 / $img.Width, 48 / $img.Height); $sw = 27 / $sc; $sh = 48 / $sc
$gs.DrawImage($img, (New-Object System.Drawing.RectangleF 0, 0, 27, 48), (New-Object System.Drawing.RectangleF (($img.Width - $sw) / 2), (($img.Height - $sh) / 2), $sw, $sh), 'Pixel'); $gs.Dispose()
$g.InterpolationMode = 'HighQualityBilinear'; $g.DrawImage($small, -40, -40, $W + 80, $H + 80); $g.InterpolationMode = 'HighQualityBicubic'
$g.FillRectangle((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(150, 10, 14, 16))), 0, 0, $W, $H)
$pw = $W; $ph = [int]($pw * $img.Height / $img.Width); $py = 560
$g.DrawImage($img, 0, $py, $pw, $ph)
Brand $g 230 104
Spaced $g $Kicker $fKick $text ($W / 2) 360 6
$fT = New-Object System.Drawing.Font($bebas, [single]118, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString("BITLLET D'ANADA,", $fT, (New-Object System.Drawing.SolidBrush $text), (New-Object System.Drawing.RectangleF 0, ($py + $ph + 50), $W, 130), (New-Object System.Drawing.StringFormat -Property @{ Alignment = 'Center' }))
$g.DrawString('ALTRA VEGADA', $fT, (New-Object System.Drawing.SolidBrush $turq), (New-Object System.Drawing.RectangleF 0, ($py + $ph + 160), $W, 130), (New-Object System.Drawing.StringFormat -Property @{ Alignment = 'Center' }))
Spaced $g $Section $fKick $muted ($W / 2) ($py + $ph + 310) 6
$g.Dispose(); Save $b 'story-instagram-B.jpg'; $b.Dispose()

# --- Variant SPLIT: foto a sang a dalt i text gran a sota, alineat a l'esquerra
$c = New-Canvas; $b = $c[0]; $g = $c[1]
$topH = 1080
$sc = [Math]::Max($W / $img.Width, $topH / $img.Height); $sw = $W / $sc; $sh = $topH / $sc
$g.DrawImage($img, (New-Object System.Drawing.RectangleF 0, 0, $W, $topH), (New-Object System.Drawing.RectangleF (($img.Width - $sw) / 2), (($img.Height - $sh) / 2), $sw, $sh), 'Pixel')
$grad = New-Object System.Drawing.Drawing2D.LinearGradientBrush (New-Object System.Drawing.Rectangle 0, 0, $W, 300), ([System.Drawing.Color]::FromArgb(170, 0, 0, 0)), ([System.Drawing.Color]::FromArgb(0, 0, 0, 0)), 90
$g.FillRectangle($grad, 0, 0, $W, 300)
Brand $g 170 80
$x0 = 80
Spaced $g $Kicker $fKick $turq $x0 1140 6 'left'
$fT2 = New-Object System.Drawing.Font($bebas, [single]150, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$g.DrawString("BITLLET D'ANADA,", $fT2, (New-Object System.Drawing.SolidBrush $text), $x0 - 6, 1195, $tf)
$g.DrawString('ALTRA VEGADA', $fT2, (New-Object System.Drawing.SolidBrush $text), $x0 - 6, 1335, $tf)
Spaced $g $Date.ToUpper() $fDate $muted $x0 1500 5 'left'
Spaced $g $Section $fDate $turq $x0 1550 5 'left'
$g.Dispose(); Save $b 'story-instagram-C.jpg'; $b.Dispose()
$img.Dispose()
