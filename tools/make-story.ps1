# Genera una imatge per a stories d'Instagram (1080x1920) amb l'estil de la targeta del blog.
param(
    [Parameter(Mandatory)] [string] $Photo,
    [Parameter(Mandatory)] [string] $Title,
    [Parameter(Mandatory)] [string] $Date,
    [Parameter(Mandatory)] [string] $Out,
    [string] $Kicker = 'NOVA ENTRADA AL BLOG',
    [string] $Section = 'SURF AL CARIB I MÉS ENLLÀ',
    [string] $Url = 'mikirosinyol.com',
    [string] $BebasFont
)
Add-Type -AssemblyName System.Drawing

$W = 1080; $H = 1920
$bg = [System.Drawing.ColorTranslator]::FromHtml('#12181b')
$card = [System.Drawing.ColorTranslator]::FromHtml('#1a2226')
$turq = [System.Drawing.ColorTranslator]::FromHtml('#4fc1cf')
$text = [System.Drawing.ColorTranslator]::FromHtml('#e8e4dc')
$muted = [System.Drawing.ColorTranslator]::FromHtml('#9aa6ab')

$pfc = New-Object System.Drawing.Text.PrivateFontCollection
$pfc.AddFontFile($BebasFont)
$bebas = $pfc.Families[0]

$bmp = New-Object System.Drawing.Bitmap $W, $H
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.InterpolationMode = 'HighQualityBicubic'
$g.TextRenderingHint = 'AntiAliasGridFit'; $g.PixelOffsetMode = 'HighQuality'
$g.Clear($bg)
# Format tipogràfic que també mesura els espais
$tf = [System.Drawing.StringFormat]::GenericTypographic.Clone()
$tf.FormatFlags = $tf.FormatFlags -bor [System.Drawing.StringFormatFlags]::MeasureTrailingSpaces

function RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r, [bool]$top = $true, [bool]$bottom = $true) {
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $r * 2
    if ($top) { $p.AddArc($x, $y, $d, $d, 180, 90); $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90) } else { $p.AddLine($x, $y, $x + $w, $y) }
    if ($bottom) { $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90); $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90) } else { $p.AddLine($x + $w, $y + $h, $x, $y + $h) }
    $p.CloseFigure(); $p
}
# Text amb espai entre lletres (System.Drawing no en té): lletra a lletra
function Spaced([string]$s, $font, $brush, [float]$cx, [float]$y, [float]$spacing) {
    $fmt = $tf
    $widths = $s.ToCharArray() | ForEach-Object { $g.MeasureString([string]$_, $font, 2000, $fmt).Width }
    $total = ($widths | Measure-Object -Sum).Sum + $spacing * ($s.Length - 1)
    $x = $cx - $total / 2
    for ($i = 0; $i -lt $s.Length; $i++) { $g.DrawString([string]$s[$i], $font, $brush, $x, $y, $fmt); $x += $widths[$i] + $spacing }
}
function Centered([string]$s, $font, $brush, [float]$y) {
    $fmt = $tf
    $w = $g.MeasureString($s, $font, 4000, $fmt).Width
    $g.DrawString($s, $font, $brush, ($W - $w) / 2, $y, $fmt)
}

# --- Capçalera: MIKI ROSINYOL
$fBrand = New-Object System.Drawing.Font($bebas, [single]96, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$fmt = $tf
$w1 = $g.MeasureString('MIKI ', $fBrand, 4000, $fmt).Width; $w2 = $g.MeasureString('ROSINYOL', $fBrand, 4000, $fmt).Width
$x = ($W - $w1 - $w2) / 2
$g.DrawString('MIKI ', $fBrand, (New-Object System.Drawing.SolidBrush $text), $x, 190, $fmt)
$g.DrawString('ROSINYOL', $fBrand, (New-Object System.Drawing.SolidBrush $turq), $x + $w1, 190, $fmt)
$fKick = New-Object System.Drawing.Font('Segoe UI Semibold', [single]30, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
Spaced $Kicker $fKick (New-Object System.Drawing.SolidBrush $muted) ($W / 2) 312 6

# --- Targeta
$cx = 80; $cy = 390; $cw = 920; $ph = [int]($cw * 3 / 4); $bh = 400
$g.FillPath((New-Object System.Drawing.SolidBrush $card), (RoundRect $cx $cy $cw ($ph + $bh) 36))
$img = [System.Drawing.Image]::FromFile($Photo)
if ($img.PropertyIdList -contains 0x0112) {
    switch ([int]$img.GetPropertyItem(0x0112).Value[0]) { 3 { $img.RotateFlip('Rotate180FlipNone') } 6 { $img.RotateFlip('Rotate90FlipNone') } 8 { $img.RotateFlip('Rotate270FlipNone') } }
}
$scale = [Math]::Max($cw / $img.Width, $ph / $img.Height)
$sw = $cw / $scale; $sh = $ph / $scale
$src = New-Object System.Drawing.RectangleF (($img.Width - $sw) / 2), (($img.Height - $sh) / 2), $sw, $sh
$g.SetClip((RoundRect $cx $cy $cw $ph 36 $true $false))
$g.DrawImage($img, (New-Object System.Drawing.RectangleF $cx, $cy, $cw, $ph), $src, 'Pixel')
$g.ResetClip(); $img.Dispose()

$fDate = New-Object System.Drawing.Font('Segoe UI Semibold', [single]32, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$fTitle = New-Object System.Drawing.Font('Georgia', [single]68, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$ty = $cy + $ph + 60
# Data alineada a l'esquerra, com a la targeta del blog
$fmtL = $tf
$xd = $cx + 56
foreach ($ch in $Date.ToUpper().ToCharArray()) { $g.DrawString([string]$ch, $fDate, (New-Object System.Drawing.SolidBrush $turq), $xd, $ty, $fmtL); $xd += $g.MeasureString([string]$ch, $fDate, 2000, $fmtL).Width + 5 }
$rect = New-Object System.Drawing.RectangleF ($cx + 56), ($ty + 62), ($cw - 112), 200
$g.DrawString($Title, $fTitle, (New-Object System.Drawing.SolidBrush $text), $rect)

# --- Sota la targeta: secció i web (deixant lloc per a l'adhesiu d'enllaç d'Instagram)
$fSec = New-Object System.Drawing.Font($bebas, [single]64, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
Spaced $Section $fSec (New-Object System.Drawing.SolidBrush $text) ($W / 2) ($cy + $ph + $bh + 70) 2
$fUrl = New-Object System.Drawing.Font('Segoe UI Semibold', [single]34, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
if ($Url -and $Url -ne '-') { Spaced $Url.ToUpper() $fUrl (New-Object System.Drawing.SolidBrush $turq) ($W / 2) ($cy + $ph + $bh + 160) 6 }

$jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]92)
New-Item -ItemType Directory -Force (Split-Path $Out) | Out-Null
$bmp.Save($Out, $jpeg, $ep)
$g.Dispose(); $bmp.Dispose()
Write-Output "Story: $Out"
