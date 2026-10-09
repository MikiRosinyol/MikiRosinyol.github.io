# Genera la web estàtica de mikirosinyol.com a partir de l'exportació de WordPress (API JSON).
# Ús: powershell -File build-site.ps1
param(
    [string] $Data = 'C:\Claude\web-mikirosinyol\backup-hostinger\extret\api',
    [string] $Site = 'C:\Claude\web-mikirosinyol\site'
)

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Web
$utf8 = New-Object System.Text.UTF8Encoding $false
$media = Join-Path $Site 'media'

$months = 'gener','febrer','març','abril','maig','juny','juliol','agost','setembre','octubre','novembre','desembre'
function Format-DateCa([datetime] $d) {
    $m = $months[$d.Month - 1]
    $de = if ($m -match '^[aeiou]') { "d'" } else { 'de ' }
    "$($d.Day) $de$m de $($d.Year)"
}
function Write-File([string] $path, [string] $text) {
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, $text, $utf8)
}
function Enc([string] $s) { [System.Web.HttpUtility]::HtmlEncode($s) }
function Dec([string] $s) { [System.Web.HttpUtility]::HtmlDecode($s) }

# Converteix una URL de wp-content/uploads a la ruta de la imatge redimensionada dins de media/
function Resolve-Image([string] $url) {
    $rel = ($url -replace '^.*?wp-content/uploads/', '') -replace '-\d+x\d+(\.\w+)$', '$1' -replace '-scaled(\.\w+)$', '$1'
    foreach ($cand in @($rel, ($rel -replace '\.\w+$', '.jpg'))) {
        if (Test-Path (Join-Path $media ($cand -replace '/', '\'))) { return $cand }
    }
    Write-Warning "Imatge no trobada: $url"
    return $null
}

$sizeCache = @{}
function Get-Size([string] $rel) {
    if (-not $sizeCache.ContainsKey($rel)) {
        $fs = [IO.File]::OpenRead((Join-Path $media ($rel -replace '/', '\')))
        try {
            $img = [System.Drawing.Image]::FromStream($fs, $false, $false)
            $sizeCache[$rel] = @($img.Width, $img.Height)
            $img.Dispose()
        } finally { $fs.Dispose() }
    }
    $sizeCache[$rel]
}

# Miniatura per a les targetes de la portada
function New-Thumb([string] $rel, [string] $slug) {
    $outRel = "thumbs/$slug.jpg"
    $out = Join-Path $media ($outRel -replace '/', '\')
    if (-not (Test-Path $out)) {
        New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
        $img = [System.Drawing.Image]::FromFile((Join-Path $media ($rel -replace '/', '\')))
        # Retall 4:3 centrat a 640x480
        $tw = 640; $th = 480
        $scale = [Math]::Max($tw / $img.Width, $th / $img.Height)
        $sw = [int]($tw / $scale); $sh = [int]($th / $scale)
        $sx = [int](($img.Width - $sw) / 2); $sy = [int](($img.Height - $sh) / 2)
        $bmp = New-Object System.Drawing.Bitmap $tw, $th
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = 'HighQualityBicubic'
        $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $tw, $th), (New-Object System.Drawing.Rectangle $sx, $sy, $sw, $sh), 'Pixel')
        $codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object MimeType -eq 'image/jpeg'
        $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
        $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]78)
        $bmp.Save($out, $codec, $ep)
        $g.Dispose(); $bmp.Dispose(); $img.Dispose()
    }
    $outRel
}

function Get-PostPath($p) {
    $d = [datetime]$p.date
    '{0:yyyy}/{0:MM}/{0:dd}/{1}/' -f $d, $p.slug
}

# Reescriu els enllaços interns de WordPress a les rutes noves
function Fix-Links([string] $html) {
    $html = $html -replace 'https?://mikirosinyol\.com/index\.php/(\d{4}/\d{2}/\d{2}/[^"/]+/?)', '/$1'
    $html = $html -replace 'https?://mikirosinyol\.com/index\.php/(inicio|lombok)/?', '/'
    $html
}

# Converteix el contingut d'Elementor en blocs simples: paràgrafs, subtítols, galeries i vídeos
function Convert-Content($p) {
    $html = $p.content.rendered -replace '(?s)<style.*?</style>', '' -replace '(?s)<script.*?</script>', ''
    $tokens = [regex]::Matches($html, '(?s)<h([2-6])[^>]*>(.*?)</h\1>|<p[^>]*>(.*?)</p>|<img [^>]*>|<video [^>]*>')
    $out = New-Object System.Text.StringBuilder
    $gallery = New-Object System.Collections.ArrayList
    $title = $p.title.rendered
    $n = 0
    $flush = {
        if ($gallery.Count -gt 0) {
            $cls = if ($gallery.Count -eq 1) { 'gallery single' } else { 'gallery' }
            [void]$out.AppendLine("<div class=""$cls"">")
            foreach ($g in $gallery) { [void]$out.AppendLine($g) }
            [void]$out.AppendLine('</div>')
            $gallery.Clear()
        }
    }
    foreach ($t in $tokens) {
        $v = $t.Value
        if ($v.StartsWith('<img')) {
            $src = [regex]::Match($v, 'src="([^"]+)"').Groups[1].Value
            $rel = Resolve-Image $src
            if (-not $rel) { continue }
            $n++
            $wh = Get-Size $rel
            $orient = if ($wh[1] -gt $wh[0]) { ' class="tall"' } else { '' }
            [void]$gallery.Add("<a href=""/media/$rel"" data-lightbox$orient><img src=""/media/$rel"" width=""$($wh[0])"" height=""$($wh[1])"" loading=""lazy"" decoding=""async"" alt=""""></a>")
        }
        elseif ($v.StartsWith('<video')) {
            & $flush
            $src = [regex]::Match($v, 'src="([^"]+)"').Groups[1].Value
            $rel = ($src -replace '^.*?wp-content/uploads/', '') -replace '\.\w+$', '.mp4'
            $poster = $rel -replace '\.mp4$', '.jpg'
            [void]$out.AppendLine("<figure class=""video""><video src=""/media/$rel"" poster=""/media/$poster"" controls preload=""none"" playsinline></video></figure>")
        }
        elseif ($t.Groups[1].Success) {
            & $flush
            $lvl = [Math]::Max(2, [int]$t.Groups[1].Value)
            [void]$out.AppendLine("<h$lvl>$($t.Groups[2].Value.Trim())</h$lvl>")
        }
        else {
            $inner = $t.Groups[3].Value.Trim()
            if ($inner -eq '' -or $inner -eq '&nbsp;') { continue }
            & $flush
            [void]$out.AppendLine("<p>$(Fix-Links $inner)</p>")
        }
    }
    & $flush
    $out.ToString()
}

function First-Image($p) {
    $m = [regex]::Match($p.content.rendered, '<img[^>]+src="([^"]+wp-content/uploads/[^"]+)"')
    if ($m.Success) { Resolve-Image $m.Groups[1].Value }
}

function Excerpt($p) {
    $m = [regex]::Match($p.content.rendered, '(?s)<p[^>]*>(.*?)</p>')
    (Dec ($m.Groups[1].Value -replace '<[^>]+>', '')).Trim()
}

# Només textos que ja eren a la web original de WordPress
$siteName = 'Miki rosinyol'
$baseUrl = 'https://mikirosinyol.com'
$instagram = 'https://www.instagram.com/mikirosinyol/'
$linkedin = 'https://www.linkedin.com/in/miquel-rosinyol-b00798132/'
# Web de Data Intelligence BCN: buit fins que existeixi. Quan hi sigui, posa-hi 'https://www.dataintelligencebcn.com/' i el logo serà un enllaç.
$dibUrl = ''
# Codi de GoatCounter (mètriques sense cookies). Buit = no es carrega.
$goatCode = ''
function Dib-Icon([string] $cls) {
    $svg = '<svg class="ico" aria-hidden="true"><use href="#i-dib"/></svg>'
    if ($dibUrl) { "<a class=`"$cls`" href=`"$dibUrl`" target=`"_blank`" rel=`"noopener`" aria-label=`"Data Intelligence BCN`">$svg</a>" }
    else { "<span class=`"$cls dib-off`" title=`"Data Intelligence BCN`" aria-label=`"Data Intelligence BCN`" role=`"img`">$svg</span>" }
}

# Versió dels fitxers d'estil i script: canvia quan canvia el contingut, perquè els navegadors no facin servir la còpia antiga
$assetVer = @{}
foreach ($a in 'style.css','site.js') { $assetVer[$a] = (Get-FileHash (Join-Path $Site "assets\$a") -Algorithm MD5).Hash.Substring(0, 8).ToLower() }

function Layout([string] $title, [string] $desc, [string] $path, [string] $image, [string] $body, [string] $bodyClass) {
    $fullTitle = if ($title -eq $siteName) { $siteName } else { "$title – $siteName" }
    $og = if ($image) { "<meta property=""og:image"" content=""$baseUrl/media/$image"">" } else { '' }
    @"
<!doctype html>
<html lang="ca">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$(Enc $fullTitle)</title>
<meta name="description" content="$(Enc $desc)">
<link rel="canonical" href="$baseUrl/$path">
<meta property="og:title" content="$(Enc $fullTitle)">
<meta property="og:description" content="$(Enc $desc)">
<meta property="og:type" content="website">
$og
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Fraunces:opsz,wght@9..144,500;9..144,700&family=Inter:wght@400;500;600&family=Bebas+Neue&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/assets/style.css?v=$($assetVer['style.css'])">
<link rel="icon" href="/assets/favicon.svg" type="image/svg+xml">
$(if ($goatCode) { "<script data-goatcounter=""https://$goatCode.goatcounter.com/count"" async src=""//gc.zgo.at/count.js""></script>" })
</head>
<body class="$bodyClass">
<svg width="0" height="0" style="position:absolute" aria-hidden="true">
  <symbol id="i-ig" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="5" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="12" cy="12" r="4.2" fill="none" stroke="currentColor" stroke-width="2"/><circle cx="17.4" cy="6.6" r="1.3" fill="currentColor"/></symbol>
  <symbol id="i-in" viewBox="0 0 24 24"><rect x="3" y="3" width="18" height="18" rx="3" fill="none" stroke="currentColor" stroke-width="2"/><rect x="7" y="10" width="2.2" height="7" fill="currentColor"/><circle cx="8.1" cy="7.4" r="1.3" fill="currentColor"/><path d="M11.5 10h2.1v1c.5-.8 1.4-1.2 2.4-1.2 1.9 0 2.7 1.2 2.7 3.2V17h-2.2v-3.6c0-1-.3-1.7-1.2-1.7s-1.6.7-1.6 1.8V17h-2.2z" fill="currentColor"/></symbol>
  <symbol id="i-dib" viewBox="0 0 100 100"><g stroke="currentColor" stroke-width="7" stroke-linecap="round"><line x1="50" y1="52" x2="20" y2="22"/><line x1="50" y1="52" x2="80" y2="24"/><line x1="50" y1="52" x2="22" y2="80"/><line x1="50" y1="52" x2="80" y2="78"/></g><circle cx="20" cy="22" r="13" fill="currentColor"/><circle cx="80" cy="24" r="10" fill="currentColor"/><circle cx="22" cy="80" r="15" fill="currentColor"/><circle cx="80" cy="78" r="11" fill="currentColor"/><circle cx="50" cy="52" r="12" fill="currentColor"/></symbol>
</svg>
<header class="topbar">
  <a class="brand" href="/">Miki <span class="surname">rosinyol</span></a>
  <nav class="nav-links" id="nav-links">
    <a href="/#lombok">Lombok</a>
    <a href="/#asia">471 dies a Àsia</a>
  </nav>
  <div class="nav-tools">
    <a class="nav-icon" href="$instagram" target="_blank" rel="noopener" aria-label="Instagram"><svg class="ico" aria-hidden="true"><use href="#i-ig"/></svg></a>
    <a class="nav-icon" href="$linkedin" target="_blank" rel="noopener" aria-label="Linkedin"><svg class="ico" aria-hidden="true"><use href="#i-in"/></svg></a>
    $(Dib-Icon 'nav-icon')
    <button class="menu-btn" type="button" aria-label="Menú" aria-expanded="false" aria-controls="nav-links"><svg class="ico" viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M4 12h16M4 17h16" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg></button>
  </div>
</header>
$body
<footer class="footer">
  <p><a href="$instagram" target="_blank" rel="noopener">Instagram</a> · <a href="$linkedin" target="_blank" rel="noopener">Linkedin</a></p>
</footer>
<script src="/assets/site.js?v=$($assetVer['site.js'])" defer></script>
</body>
</html>
"@
}

# --- Dades
$posts = @(Get-Content (Join-Path $Data 'posts.json') -Raw -Encoding UTF8 | ConvertFrom-Json)
$posts = @($posts | ForEach-Object { $_ } | Sort-Object { [datetime]$_.date })
$lombokSlugs = @('nova-aventura')
$asia = @($posts | Where-Object { $lombokSlugs -notcontains $_.slug })
$lombok = @($posts | Where-Object { $lombokSlugs -contains $_.slug })

# --- Entrades
for ($i = 0; $i -lt $posts.Count; $i++) {
    $p = $posts[$i]
    $title = Dec $p.title.rendered
    $date = [datetime]$p.date
    $path = Get-PostPath $p
    $cover = First-Image $p
    $content = Convert-Content $p
    $prev = if ($i -gt 0) { $posts[$i - 1] } else { $null }
    $next = if ($i -lt $posts.Count - 1) { $posts[$i + 1] } else { $null }
    $nav = '<nav class="post-nav">'
    if ($prev) { $nav += "<a class=""prev"" href=""/$(Get-PostPath $prev)""><span>←</span>$(Enc (Dec $prev.title.rendered))</a>" } else { $nav += '<span></span>' }
    if ($next) { $nav += "<a class=""next"" href=""/$(Get-PostPath $next)""><span>→</span>$(Enc (Dec $next.title.rendered))</a>" }
    $nav += '</nav>'
    $body = @"
<main class="post">
  <header class="post-head">
    <h1>$(Enc $title)</h1>
    <p class="date"><time datetime="$($date.ToString('yyyy-MM-dd'))">$(Format-DateCa $date)</time></p>
  </header>
  <article class="prose">
$content
  </article>
  $nav
</main>
"@
    Write-File (Join-Path $Site (($path -replace '/', '\') + 'index.html')) (Layout $title (Excerpt $p) $path $cover $body 'page-post')
    # Redirecció des de l'URL antiga de WordPress
    $old = "index.php/$path"
    Write-File (Join-Path $Site (($old -replace '/', '\') + 'index.html')) "<!doctype html><meta charset=""utf-8""><title>$(Enc $title)</title><link rel=""canonical"" href=""$baseUrl/$path""><meta http-equiv=""refresh"" content=""0; url=/$path""><a href=""/$path"">$(Enc $title)</a>"
}
foreach ($old in 'index.php/inicio/', 'index.php/lombok/', 'index.php/') {
    Write-File (Join-Path $Site (($old -replace '/', '\') + 'index.html')) '<!doctype html><meta charset="utf-8"><meta http-equiv="refresh" content="0; url=/"><a href="/">Miki rosinyol</a>'
}

# --- Portada
function Card($p) {
    $img = First-Image $p
    $thumb = if ($img) { New-Thumb $img $p.slug } else { $null }
    $date = [datetime]$p.date
    $imgTag = if ($thumb) { "<img src=""/media/$thumb"" width=""640"" height=""480"" loading=""lazy"" decoding=""async"" alt="""">" } else { '' }
    @"
<a class="card" href="/$(Get-PostPath $p)">
  <div class="card-img">$imgTag</div>
  <div class="card-body">
    <time datetime="$($date.ToString('yyyy-MM-dd'))">$(Format-DateCa $date)</time>
    <h3>$(Enc (Dec $p.title.rendered))</h3>
  </div>
</a>
"@
}

# Foto de portada triada per en Miki (entrada "La comunitat")
$heroImg = '2024/11/thumbnail_IMG_8346.jpg'
$asiaCards = ($asia | Sort-Object { [datetime]$_.date } -Descending | ForEach-Object { Card $_ }) -join "`n"
$lombokCards = ($lombok | ForEach-Object { Card $_ }) -join "`n"

# Títol de secció: marca la primera paraula (o lletra) amb .t per si es vol destacar amb CSS
function Section-Title([string] $txt) {
    $i = $txt.IndexOf(' ')
    if ($i -gt 0) { "<span class=`"t`">$(Enc $txt.Substring(0, $i))</span>$(Enc $txt.Substring($i))" }
    else { "<span class=`"t`">$(Enc $txt.Substring(0, 1))</span>$(Enc $txt.Substring(1))" }
}

$homeHtml = @"
<section class="hero" style="--hero: url('/media/$heroImg')">
  <div class="hero-inner">
    <h1><span>Miki</span> <span class="surname">rosinyol</span></h1>
    <div class="hero-line">
      <p class="lead">ONE LIFE</p>
      <span class="sep" aria-hidden="true"></span>
      <a href="$instagram" target="_blank" rel="noopener" aria-label="Instagram"><svg class="ico" aria-hidden="true"><use href="#i-ig"/></svg></a>
      <a href="$linkedin" target="_blank" rel="noopener" aria-label="Linkedin"><svg class="ico" aria-hidden="true"><use href="#i-in"/></svg></a>
      $(Dib-Icon 'hero-icon')
    </div>
  </div>
</section>
<main>
  <section class="chapter" id="lombok">
    <div class="chapter-head">
      <h2 class="sh">$(Section-Title 'Lombok')</h2>
    </div>
    <div class="grid">$lombokCards</div>
  </section>
  <section class="chapter" id="asia">
    <div class="chapter-head">
      <h2 class="sh">$(Section-Title '471 dies a Àsia')</h2>
    </div>
    <div class="grid">$asiaCards</div>
  </section>
</main>
"@
Write-File (Join-Path $Site 'index.html') (Layout $siteName 'ONE LIFE' '' $heroImg $homeHtml 'page-home')

# --- 404 (sense text propi: només l'enllaç a l'inici) i fitxers de GitHub Pages
Write-File (Join-Path $Site '404.html') (Layout $siteName '' '404.html' '' "<main class=""post""><header class=""post-head""><h1><a href=""/"">$siteName</a></h1></header></main>" 'page-post')
Write-File (Join-Path $Site '.nojekyll') ''

# --- Sitemap i robots.txt per als cercadors
$urls = New-Object System.Text.StringBuilder
[void]$urls.AppendLine("<url><loc>$baseUrl/</loc><lastmod>$(([datetime]$posts[-1].modified).ToString('yyyy-MM-dd'))</lastmod></url>")
foreach ($p in $posts) { [void]$urls.AppendLine("<url><loc>$baseUrl/$(Get-PostPath $p)</loc><lastmod>$(([datetime]$p.modified).ToString('yyyy-MM-dd'))</lastmod></url>") }
Write-File (Join-Path $Site 'sitemap.xml') ("<?xml version=""1.0"" encoding=""UTF-8""?>`n<urlset xmlns=""http://www.sitemaps.org/schemas/sitemap/0.9"">`n" + $urls.ToString() + "</urlset>`n")
Write-File (Join-Path $Site 'robots.txt') "User-agent: *`nAllow: /`n`nSitemap: $baseUrl/sitemap.xml`n"
Write-Output "Generades $($posts.Count) entrades, $($sizeCache.Count) fotos referenciades."
