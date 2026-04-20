$source = "C:\Users\Frex\Documents\Notizen\Private\blog"
$dest   = "C:\Users\Frex\Documents\flowspirit\content\posts"

$global:lastRun = Get-Date

function Process-Files {

    Write-Host "`n=== SYNC START ==="

    Get-ChildItem $source -Directory | ForEach-Object {

        $folder = $_
        $bundleName = $folder.Name
        $bundlePath = Join-Path $dest $bundleName

        # 🔥 NEU: einfach erste .md Datei im Ordner nehmen
        $mdFile = Get-ChildItem $folder.FullName -Filter "*.md" | Select-Object -First 1

        if (-not $mdFile) {
            Write-Warning "Keine Markdown-Datei in: $($folder.FullName)"
            return
        }

        if (!(Test-Path $bundlePath)) {
            New-Item -ItemType Directory -Path $bundlePath | Out-Null
        }

        $targetFile = Join-Path $bundlePath "index.md"
        $content = Get-Content $mdFile.FullName -Raw -Encoding UTF8

        # Obsidian Wikilinks → Markdown
        $content = [regex]::Replace($content, '!\[\[(.*?)\]\]', {
            param($m)
            $img = $m.Groups[1].Value.Split('|')[0]
            return "![]($img)"
        })

        # Bilder finden
        $matches = [regex]::Matches($content, '!\[.*?\]\((.*?)\)')

        foreach ($match in $matches) {

            $imgPath = $match.Groups[1].Value.Trim()
            $fileName = Split-Path $imgPath -Leaf

            $c1 = Join-Path $folder.FullName $imgPath
            $c2 = Join-Path $folder.FullName "attachments\$fileName"
            $c3 = Join-Path $folder.FullName $fileName

            $sourceImg = $null
            if (Test-Path $c1) { $sourceImg = $c1 }
            elseif (Test-Path $c2) { $sourceImg = $c2 }
            elseif (Test-Path $c3) { $sourceImg = $c3 }

            $destImg = Join-Path $bundlePath $fileName

            if ($sourceImg) {
                Copy-Item $sourceImg $destImg -Force
                Write-Host "✔ Bild: $fileName"
            }
            else {
                Write-Warning "❌ Bild nicht gefunden: $imgPath"
            }
        }

        # Markdown fix (nur Dateiname)
        $content = [regex]::Replace($content, '!\[(.*?)\]\((.*?)\)', {
            param($m)
            $alt = $m.Groups[1].Value
            $path = $m.Groups[2].Value
            $fileName = Split-Path $path -Leaf
            return "![$alt]($fileName)"
        })

        $utf8 = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($targetFile, $content, $utf8)
    }

    Write-Host "`n=== SYNC END ==="
}

# Watcher
$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $source
$watcher.Filter = "*"
$watcher.IncludeSubdirectories = $true
$watcher.EnableRaisingEvents = $true

Register-ObjectEvent $watcher Changed -Action {
    $now = Get-Date
    if (($now - $global:lastRun).TotalMilliseconds -gt 1000) {
        $global:lastRun = $now
        Process-Files
    }
}

Register-ObjectEvent $watcher Created -Action {
    $now = Get-Date
    if (($now - $global:lastRun).TotalMilliseconds -gt 1000) {
        $global:lastRun = $now
        Process-Files
    }
}

Write-Host "Watcher läuft..."

Process-Files

while ($true) { Start-Sleep 1 }