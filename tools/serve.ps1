# Servidor local mínim per previsualitzar la web estàtica (http://localhost:8080)
param([string] $Root = 'C:\Claude\web-mikirosinyol\site', [int] $Port = 8080)

$types = @{
    '.html' = 'text/html; charset=utf-8'; '.css' = 'text/css; charset=utf-8'; '.js' = 'application/javascript; charset=utf-8'
    '.svg' = 'image/svg+xml'; '.jpg' = 'image/jpeg'; '.png' = 'image/png'; '.mp4' = 'video/mp4'; '.json' = 'application/json'
}
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Output "Servint $Root a http://localhost:$Port/"
while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $path = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/') -replace '/', '\'
    $file = Join-Path $Root $path
    if (Test-Path $file -PathType Container) { $file = Join-Path $file 'index.html' }
    $res = $ctx.Response
    try {
        if (-not (Test-Path $file -PathType Leaf)) { $res.StatusCode = 404; $file = Join-Path $Root '404.html' }
        $ext = [IO.Path]::GetExtension($file).ToLower()
        $res.ContentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { 'application/octet-stream' }
        $bytes = [IO.File]::ReadAllBytes($file)
        $res.ContentLength64 = $bytes.Length
        $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } catch { } finally { $res.OutputStream.Close() }
}
