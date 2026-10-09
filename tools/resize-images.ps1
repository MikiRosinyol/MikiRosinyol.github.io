# Redimensiona les imatges originals del backup de WordPress per a la web estàtica.
# Ús: powershell -File resize-images.ps1 -Src <uploads> -Dst <site\media> -List <llista.txt>
param(
    [Parameter(Mandatory)] [string] $Src,
    [Parameter(Mandatory)] [string] $Dst,
    [Parameter(Mandatory)] [string] $List,
    [int] $MaxSize = 1600,
    [int] $Quality = 80
)

Add-Type -AssemblyName System.Drawing
$jpegCodec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
$encParams = New-Object System.Drawing.Imaging.EncoderParameters 1
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]$Quality)

$files = Get-Content $List
$i = 0; $errors = 0
foreach ($rel in $files) {
    $i++
    $in = Join-Path $Src ($rel -replace '/', '\')
    # Totes les sortides en JPEG excepte els PNG petits (logos, captures)
    $isPng = $rel -match '\.png$'
    $outRel = if ($isPng -and (Get-Item $in).Length -lt 300KB) { $rel } else { $rel -replace '\.\w+$', '.jpg' }
    $out = Join-Path $Dst ($outRel -replace '/', '\')
    if (Test-Path $out) { continue }
    New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
    try {
        $img = [System.Drawing.Image]::FromFile($in)
        # Respecta l'orientació EXIF de les fotos del mòbil
        if ($img.PropertyIdList -contains 0x0112) {
            switch ([int]$img.GetPropertyItem(0x0112).Value[0]) {
                3 { $img.RotateFlip('Rotate180FlipNone') }
                6 { $img.RotateFlip('Rotate90FlipNone') }
                8 { $img.RotateFlip('Rotate270FlipNone') }
            }
        }
        $scale = [Math]::Min(1.0, $MaxSize / [Math]::Max($img.Width, $img.Height))
        $w = [int]($img.Width * $scale); $h = [int]($img.Height * $scale)
        $bmp = New-Object System.Drawing.Bitmap $w, $h
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = 'HighQualityBicubic'
        $g.Clear([System.Drawing.Color]::White)
        $g.DrawImage($img, 0, 0, $w, $h)
        if ($outRel -match '\.png$') { $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png) }
        else { $bmp.Save($out, $jpegCodec, $encParams) }
        $g.Dispose(); $bmp.Dispose(); $img.Dispose()
    } catch {
        $errors++
        Write-Output "ERROR $rel : $($_.Exception.Message)"
    }
    if ($i % 100 -eq 0) { Write-Output "$i / $($files.Count)" }
}
$size = (Get-ChildItem $Dst -Recurse -File | Measure-Object Length -Sum).Sum
Write-Output "Fet: $($files.Count) imatges, $errors errors, $([math]::Round($size/1MB)) MB"
