# Importa una entrada nova (Word + fotos + maqueta.json) al contingut del blog.
# - Llegeix el text del Word tal qual (primera línia = títol). Ignora els paràgrafs blaus de propostes.
# - Redueix les fotos a 1600 px (respectant l'orientació EXIF) i les desa a site/media/AAAA/MM/<slug>/.
# - Escriu contingut/entrades/<data>-<slug>.json, que llegeix build-site.ps1.
# Ús: powershell -File import-entry.ps1 -Entry <carpeta de l'entrada>
param(
    [Parameter(Mandatory)] [string] $Entry,
    [string] $Site = 'C:\Claude\web-mikirosinyol\site',
    [string] $Out = 'C:\Claude\web-mikirosinyol\contingut\entrades',
    [int] $MaxSize = 1600,
    [int] $Quality = 82
)

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$utf8 = New-Object System.Text.UTF8Encoding $false

$maq = Get-Content (Join-Path $Entry 'maqueta.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$date = [datetime]$maq.date
$mediaRel = '{0:yyyy}/{0:MM}/{1}' -f $date, $maq.slug

# --- Text del Word, sense bloquejar-lo
$docx = Join-Path $Entry 'entrada.docx'
$fs = [IO.File]::Open($docx, 'Open', 'Read', 'ReadWrite')
$zip = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Read)
$sr = New-Object IO.StreamReader($zip.GetEntry('word/document.xml').Open())
$xml = $sr.ReadToEnd(); $sr.Close(); $zip.Dispose(); $fs.Close()
$paras = @{}
$n = 0
foreach ($m in [regex]::Matches($xml, '(?s)<w:p\b(?:(?!<w:p\b).)*?</w:p>')) {
    $n++
    if ($m.Value -match 'w:color w:val="0070C0"') { continue }   # propostes de Claude
    $t = ([regex]::Matches($m.Value, '<w:t[^>]*>([^<]*)</w:t>') | ForEach-Object { $_.Groups[1].Value }) -join ''
    $t = [System.Net.WebUtility]::HtmlDecode($t).Trim()
    if ($t) { $paras[$n] = $t }
}
$order = $paras.Keys | Sort-Object
$title = $paras[$order[0]]

# --- Fotos: es busquen pel prefix numèric del nom ("01 - ...")
$photos = Get-ChildItem (Join-Path $Entry 'fotos') -File | Where-Object Extension -match '^\.(jpe?g|png)$'
function Find-Photo([string] $key) {
    $hit = $photos | Where-Object { $_.Name -match ('^' + [regex]::Escape($key) + '\s*-') }
    if (@($hit).Count -ne 1) { throw "Foto '$key': trobades $(@($hit).Count)" }
    $hit
}

$jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
$ep = New-Object System.Drawing.Imaging.EncoderParameters 1
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]$Quality)

function Save-Photo([IO.FileInfo] $file, [string] $name) {
    $outRel = "$mediaRel/$name.jpg"
    $out = Join-Path $Site ('media\' + ($outRel -replace '/', '\'))
    New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
    $img = [System.Drawing.Image]::FromFile($file.FullName)
    try {
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
        $g.DrawImage($img, 0, 0, $w, $h)
        $bmp.Save($out, $jpeg, $ep)
        $g.Dispose(); $bmp.Dispose()
    } finally { $img.Dispose() }
    @{ src = $outRel; w = $w; h = $h }
}

# --- Blocs: cada paràgraf i, darrere, les fotos que li toquen
$blocks = New-Object System.Collections.ArrayList
$used = @{}
foreach ($k in $order | Select-Object -Skip 1) {
    [void]$blocks.Add(@{ type = 'p'; text = $paras[$k] })
    $keys = $maq.after."$k"
    if ($keys) {
        $imgs = @()
        foreach ($key in $keys) {
            $f = Find-Photo $key
            $name = ($key -replace '\s+', '').ToLower()
            $info = Save-Photo $f $name
            $cap = $maq.captions."$key"
            if ($cap) { $info.place = $cap[0]; $info.country = $cap[1] }
            $imgs += $info
            $used[$key] = $true
        }
        [void]$blocks.Add(@{ type = 'gallery'; images = $imgs })
    }
}
$missing = $photos | Where-Object { $_.Name -match '^(\d+(\s*[A-Za-z])?)\s*-' -and -not $used[$Matches[1].Trim()] }
foreach ($m in $missing) { Write-Warning "Foto no col·locada: $($m.Name)" }

$data = [ordered]@{ title = $title; date = $maq.date; slug = $maq.slug; trip = $maq.trip; blocks = $blocks }
# Esborrany: es publica en una adreça secreta, fora de la portada, el menú i Google
if ($maq.draft) { $data.draft = $true; $data.draftToken = $maq.draftToken }
# Foto de portada de l'entrada (targeta de la portada i vista prèvia en compartir)
if ($maq.cover) { $data.cover = "$mediaRel/$(($maq.cover -replace '\s+', '').ToLower()).jpg" }
New-Item -ItemType Directory -Force $Out | Out-Null
$file = Join-Path $Out ('{0}-{1}.json' -f $maq.date, $maq.slug)
[IO.File]::WriteAllText($file, ($data | ConvertTo-Json -Depth 8), $utf8)
Write-Output "Entrada '$title': $(@($blocks | Where-Object { $_.type -eq 'p' }).Count) paràgrafs, $($used.Count) fotos -> $file"
