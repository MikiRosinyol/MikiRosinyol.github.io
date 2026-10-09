# Converteix els vídeos del backup (.mov/.mp4) a MP4 H.264 720p + pòster JPG per a la web estàtica.
param(
    [Parameter(Mandatory)] [string] $Src,
    [Parameter(Mandatory)] [string] $Dst,
    [Parameter(Mandatory)] [string] $List
)

$ffmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $ffmpeg) {
    $ffmpeg = Get-ChildItem (Join-Path $env:LOCALAPPDATA 'Microsoft\WinGet\Packages') -Recurse -Filter ffmpeg.exe |
        Select-Object -First 1 -ExpandProperty FullName
}
foreach ($rel in Get-Content $List) {
    $in = Join-Path $Src ($rel -replace '/', '\')
    $outRel = $rel -replace '\.\w+$', '.mp4'
    $out = Join-Path $Dst ($outRel -replace '/', '\')
    $poster = $out -replace '\.mp4$', '.jpg'
    New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
    if (-not (Test-Path $out)) {
        & $ffmpeg -hide_banner -loglevel error -y -i $in `
            -vf "scale='if(gt(iw,ih),-2,720)':'if(gt(iw,ih),720,-2)'" `
            -c:v libx264 -preset slow -crf 26 -pix_fmt yuv420p `
            -c:a aac -b:a 96k -movflags +faststart $out
    }
    if (-not (Test-Path $poster)) {
        & $ffmpeg -hide_banner -loglevel error -y -ss 1 -i $out -frames:v 1 -q:v 4 $poster
    }
    Write-Output ("{0}  {1:N1} MB" -f $outRel, ((Get-Item $out).Length / 1MB))
}
