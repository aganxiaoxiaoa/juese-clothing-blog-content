param(
    [switch]$Scan,
    [switch]$CleanSafe,
    [switch]$Json,
    [int]$Top = 30
)

$ErrorActionPreference = 'SilentlyContinue'
if (-not $Scan -and -not $CleanSafe) { $Scan = $true }
if ($Top -lt 1) { $Top = 30 }

$Targets = @(
    'C:\Users\Administrator\AppData\Local\Temp',
    'C:\Windows\Temp',
    'C:\Users\Administrator\Desktop',
    'C:\Users\Administrator\Downloads',
    'C:\Users\Administrator\.openclaw',
    'D:\bot',
    'D:\bot\openclaw_data\.openclaw',
    'D:\bot\video'
)

$ProtectedKeywords = @(
    'openclaw.json','credentials','telegram','scripts','workspace',
    'C:\Users\Administrator\Desktop','C:\Users\Administrator\Downloads'
)

function Format-Size([double]$bytes) {
    if ($bytes -ge 1GB) { return ('{0:N2} GB' -f ($bytes / 1GB)) }
    if ($bytes -ge 1MB) { return ('{0:N2} MB' -f ($bytes / 1MB)) }
    if ($bytes -ge 1KB) { return ('{0:N2} KB' -f ($bytes / 1KB)) }
    return ("$bytes B")
}

function Get-DirSize([string]$path) {
    if (-not (Test-Path $path)) { return 0 }
    return (Get-ChildItem -LiteralPath $path -Force -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
}

function Is-Protected([string]$path) {
    foreach ($k in $ProtectedKeywords) {
        if ($path -like "*$k*") { return $true }
    }
    return $false
}

$drives = @('C','D') | ForEach-Object {
    $d = Get-PSDrive -Name $_ -ErrorAction SilentlyContinue
    if ($d) {
        [PSCustomObject]@{
            Drive = "$($_):"
            Free = $d.Free
            Used = ($d.Used)
        }
    }
}

$folderStats = foreach ($t in $Targets) {
    [PSCustomObject]@{
        Path = $t
        Size = Get-DirSize $t
        Exists = (Test-Path $t)
    }
}

$topFolders = $folderStats | Where-Object Exists | Sort-Object Size -Descending | Select-Object -First $Top

$cleanCandidates = @(
    [PSCustomObject]@{ Name='Temp >2h (User)'; Path='C:\Users\Administrator\AppData\Local\Temp'; Rule='OlderThan2Hours' },
    [PSCustomObject]@{ Name='Temp >2h (Windows)'; Path='C:\Windows\Temp'; Rule='OlderThan2Hours' },
    [PSCustomObject]@{ Name='Photoshop Temp*'; Path='C:\'; Rule='PhotoshopTemp' },
    [PSCustomObject]@{ Name='OpenClaw logs'; Path='C:\Users\Administrator\.openclaw\logs'; Rule='Direct' },
    [PSCustomObject]@{ Name='OpenClaw media inbound'; Path='C:\Users\Administrator\.openclaw\media\inbound'; Rule='Direct' },
    [PSCustomObject]@{ Name='openclaw.json.bak*'; Path='C:\Users\Administrator\.openclaw'; Rule='BakFiles' },
    [PSCustomObject]@{ Name='npm cache'; Path='C:\Users\Administrator\AppData\Local\npm-cache'; Rule='Direct' },
    [PSCustomObject]@{ Name='pip cache'; Path='C:\Users\Administrator\AppData\Local\pip\Cache'; Rule='Direct' },
    [PSCustomObject]@{ Name='Recycle Bin'; Path='C:\$Recycle.Bin'; Rule='RecycleBin' }
)

$cleanResult = @()
foreach ($c in $cleanCandidates) {
    $size = 0
    if (Test-Path $c.Path) { $size = Get-DirSize $c.Path }
    $cleanResult += [PSCustomObject]@{ Name=$c.Name; Path=$c.Path; Size=$size; Rule=$c.Rule }
}

if ($CleanSafe) {
    foreach ($c in $cleanCandidates) {
        if (Is-Protected $c.Path) { continue }
        switch ($c.Rule) {
            'OlderThan2Hours' {
                if (Test-Path $c.Path) {
                    Get-ChildItem -LiteralPath $c.Path -Force -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { -not $_.PSIsContainer -and $_.LastWriteTime -lt (Get-Date).AddHours(-2) } |
                        Remove-Item -Force -ErrorAction SilentlyContinue
                }
            }
            'PhotoshopTemp' {
                Get-ChildItem -Path 'C:\' -Filter 'Photoshop Temp*' -Force -Recurse -File -ErrorAction SilentlyContinue |
                    Remove-Item -Force -ErrorAction SilentlyContinue
            }
            'BakFiles' {
                if (Test-Path $c.Path) {
                    Get-ChildItem -LiteralPath $c.Path -Filter 'openclaw.json.bak*' -Force -File -ErrorAction SilentlyContinue |
                        Remove-Item -Force -ErrorAction SilentlyContinue
                }
            }
            'RecycleBin' {
                Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            }
            default {
                if (Test-Path $c.Path) {
                    Get-ChildItem -LiteralPath $c.Path -Force -Recurse -ErrorAction SilentlyContinue |
                        Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
                }
            }
        }
    }
}

$output = [PSCustomObject]@{
    Mode = if ($CleanSafe) { 'clean-safe' } else { 'scan' }
    Drives = $drives
    TopFolders = $topFolders | ForEach-Object {
        [PSCustomObject]@{ Path=$_.Path; Size=Format-Size $_.Size; Bytes=$_.Size }
    }
    Cleanable = $cleanResult | Sort-Object Size -Descending | ForEach-Object {
        [PSCustomObject]@{ Item=$_.Name; Path=$_.Path; Size=Format-Size $_.Size; Bytes=$_.Size }
    }
    Note = '删除仅在 -CleanSafe 下执行；Desktop/Downloads/业务目录受保护。'
}

if ($Json) {
    $output | ConvertTo-Json -Depth 5
} else {
    Write-Host "[磁盘助手] 模式: $($output.Mode)"
    foreach ($d in $output.Drives) {
        Write-Host ("- {0} 剩余: {1}" -f $d.Drive, (Format-Size $d.Free))
    }
    Write-Host "`n[Top 文件夹]"
    $output.TopFolders | ForEach-Object { Write-Host ("- {0} | {1}" -f $_.Path, $_.Size) }
    Write-Host "`n[可清理项目]"
    $output.Cleanable | ForEach-Object { Write-Host ("- {0} | {1}" -f $_.Item, $_.Size) }
    Write-Host "`n$($output.Note)"
}
