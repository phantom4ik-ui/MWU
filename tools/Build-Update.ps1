param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+(\.\d+){0,2}$')]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$')]
    [string]$Repository,

    [Parameter(Mandatory = $true)]
    [string]$InputDirectory,

    [string]$OutputDirectory = (Join-Path $PSScriptRoot "output\$Version")
)

$ErrorActionPreference = 'Stop'
$inputRoot = (Resolve-Path -LiteralPath $InputDirectory).Path
$outputRoot = [System.IO.Path]::GetFullPath($OutputDirectory)
if (Test-Path -LiteralPath $outputRoot) {
    throw "Папка результата уже существует: $outputRoot. Укажи новую папку или новую версию обновления."
}

$profileNames = @('uprise', 'modded')
$allowedRoots = @('mods', 'resourcepacks', 'config')
$profiles = [ordered]@{}
$outputParent = Split-Path -Parent $outputRoot
New-Item -ItemType Directory -Path $outputParent -Force | Out-Null
New-Item -ItemType Directory -Path $outputRoot | Out-Null
$feedRoot = Join-Path $outputRoot 'upload\launcher-updates'
$versionRoot = Join-Path $feedRoot $Version
New-Item -ItemType Directory -Path $versionRoot -Force | Out-Null

try {
    Add-Type -AssemblyName System.IO.Compression.FileSystem

    foreach ($profile in $profileNames) {
        $profileRoot = Join-Path $inputRoot $profile
        if (-not (Test-Path -LiteralPath $profileRoot -PathType Container)) { continue }

        $profileItems = Get-ChildItem -LiteralPath $profileRoot -Force
        foreach ($item in $profileItems) {
            if (-not $item.PSIsContainer -or $allowedRoots -notcontains $item.Name) {
                throw "В $profileRoot разрешены только папки mods, resourcepacks и config. Найдено: $($item.Name)"
            }
        }

        $files = Get-ChildItem -LiteralPath $profileRoot -File -Recurse
        if ($files.Count -eq 0) {
            throw "Папка профиля '$profile' пуста: $profileRoot"
        }

        $packageName = "$profile-$Version.zip"
        $packagePath = Join-Path $versionRoot $packageName
        [System.IO.Compression.ZipFile]::CreateFromDirectory(
            $profileRoot,
            $packagePath,
            [System.IO.Compression.CompressionLevel]::Optimal,
            $false
        )

        $hash = (Get-FileHash -LiteralPath $packagePath -Algorithm SHA256).Hash.ToLowerInvariant()
        $size = (Get-Item -LiteralPath $packagePath).Length
        $profiles[$profile] = [ordered]@{
            version = $Version
            packageUrl = "https://raw.githubusercontent.com/$Repository/main/launcher-updates/$Version/$packageName"
            sha256 = $hash
            size = $size
        }
    }

    if ($profiles.Count -eq 0) {
        throw "Не найдены папки профилей uprise или modded в $inputRoot"
    }

    $manifest = [ordered]@{
        schemaVersion = 1
        profiles = $profiles
    }
    $json = $manifest | ConvertTo-Json -Depth 8
    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText((Join-Path $feedRoot 'manifest.json'), $json, $encoding)

    Write-Host "Готово. Скопируй содержимое папки $(Join-Path $outputRoot 'upload') в корень репозитория $Repository и отправь коммит в main:" -ForegroundColor Green
    Get-ChildItem -LiteralPath (Join-Path $outputRoot 'upload') -File -Recurse | Select-Object FullName, Length
}
catch {
    if (Test-Path -LiteralPath $outputRoot) {
        Remove-Item -LiteralPath $outputRoot -Recurse -Force
    }
    throw
}
