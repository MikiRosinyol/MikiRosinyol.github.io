# mikirosinyol.com

Diari de viatge "471 dies a Àsia", migrat de WordPress (Hostinger) a una web estàtica publicada amb GitHub Pages.

## Estructura

- `site/` — la web publicada (HTML, CSS, fotos i vídeos). És l'única carpeta que es desplega.
- `tools/` — scripts de PowerShell que van generar la web a partir de la còpia de seguretat de WordPress:
  - `resize-images.ps1` — redueix les fotos originals a 1600 px.
  - `convert-videos.ps1` — converteix els vídeos .mov a MP4 720p (necessita FFmpeg).
  - `build-site.ps1` — genera totes les pàgines HTML.
  - `serve.ps1` — servidor local per previsualitzar a http://localhost:8080.
- `backup-hostinger/` — còpia de seguretat original. **No es puja a GitHub** (`.gitignore`).

## Publicar canvis

Qualsevol `push` a `main` torna a publicar la web automàticament (`.github/workflows/pages.yml`).
