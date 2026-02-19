param (
    [string]$ProjectName,
    [string]$ProjectNames,   # CSV or JSON array string
    [string]$RootPath,
    [string]$GithubOwner,
    [string]$GithubRepo,
    [string]$Verbose
)

# Verbose plumbing
if ($Verbose -eq 'verbose'){
    Write-Verbose "ProjectName: $ProjectName"
    Write-Verbose "RootPath: $RootPath"
    Write-Verbose "GithubOwner: $GithubOwner"
    Write-Verbose "GithubRepo: $GithubRepo"
    Write-Verbose "ProjectNames (raw): $ProjectNames"
}

try {
    # --- Parse multi-project list ---------------------------------------------------
    [string[]]$ResolvedProjects = @()
    if ($ProjectNames) {
        $trimmed = $ProjectNames.Trim()
        if ($trimmed.StartsWith('[')) {
            try {
                $ResolvedProjects = (ConvertFrom-Json -InputObject $trimmed) | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ }
                if ($Verbose -eq 'verbose'){Write-Verbose "Parsed ProjectNames from JSON: $($ResolvedProjects -join ', ')"}
            } catch {
                if ($Verbose -eq 'verbose'){Write-Verbose "Failed to parse JSON ProjectNames; will try CSV. Error: $_"}
            }
        }
        if (-not $ResolvedProjects -and $trimmed) {
            $ResolvedProjects = $trimmed -split '\s*,\s*' | Where-Object { $_ }
            if ($Verbose -eq 'verbose'){Write-Verbose "Parsed ProjectNames from CSV: $($ResolvedProjects -join ', ')"}
        }
    }
    if (-not $ResolvedProjects -or $ResolvedProjects.Count -eq 0) {
        $ResolvedProjects = @($ProjectName)
        if ($Verbose -eq 'verbose'){Write-Verbose "No multi-project list provided; using ProjectName for NuGet badge: $ProjectName"}
    }

    # --- Try Directory.Build.props once (shared values) -----------------------------
    [xml]$Props = $null
    $BuildPropsPath = Join-Path -Path $RootPath -ChildPath "Directory.Build.props"
    if (Test-Path $BuildPropsPath) {
        try {
            $Props = [xml](Get-Content $BuildPropsPath)
            if ($Verbose -eq 'verbose'){Write-Verbose "Loaded Directory.Build.props: $BuildPropsPath"}
        } catch {
            if ($Verbose -eq 'verbose'){Write-Verbose "Failed to parse Directory.Build.props: $_"}
        }
    } else {
        if ($Verbose -eq 'verbose'){Write-Verbose "Directory.Build.props not found at root."}
    }

    # --- Auto-detect project types and generate appropriate badges -------------------
    $GalleryBadges = New-Object System.Collections.Generic.List[string]
    foreach ($p in $ResolvedProjects) {
        if ($Verbose -eq 'verbose'){Write-Verbose "Auto-detecting project type for '$p'..."}

        $badge = $null
        $projectId = $null

        # Check for PowerShell module first (.psd1 file)
        $psd1File = Get-ChildItem -Path $RootPath -Recurse -Filter "$p.psd1" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($psd1File) {
            if ($Verbose -eq 'verbose'){Write-Verbose "Found PowerShell manifest: $($psd1File.FullName)"}
            try {
                # Parse the .psd1 file to get module name (usually the filename itself)
                $manifestData = Import-PowerShellDataFile -Path $psd1File.FullName -ErrorAction SilentlyContinue
                $moduleName = $manifestData.ModuleName
                if (-not $moduleName) {
                    # Fallback to the .psd1 filename without extension
                    $moduleName = $psd1File.BaseName
                }
                $projectId = $moduleName
                $badge = "[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/$($projectId)?label=$($projectId))](https://www.powershellgallery.com/packages/$($projectId))"
                if ($Verbose -eq 'verbose'){Write-Verbose "Generated PowerShell Gallery badge for module: $projectId"}
            } catch {
                if ($Verbose -eq 'verbose'){Write-Verbose "Failed to parse PowerShell manifest '$($psd1File.FullName)', using filename: $_"}
                $projectId = $psd1File.BaseName
                $badge = "[![PowerShell Gallery](https://img.shields.io/powershellgallery/dt/$($projectId)?label=$($projectId))](https://www.powershellgallery.com/packages/$($projectId))"
            }
        }
        # If no .psd1, check for .NET project (.csproj file)
        else {
            $projFile = Get-ChildItem -Path $RootPath -Recurse -Filter "$p.csproj" -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($projFile) {
                if ($Verbose -eq 'verbose'){Write-Verbose "Found .NET project: $($projFile.FullName)"}
                try {
                    $projXml = [xml](Get-Content -Path $projFile.FullName)
                    $projectId = $projXml.Project.PropertyGroup.PackageId
                    if ($projectId) {
                        if ($Verbose -eq 'verbose'){Write-Verbose "PackageId from csproj: $projectId"}
                    } else {
                        $asm = $projXml.Project.PropertyGroup.AssemblyName
                        if ($asm) {
                            $projectId = $asm
                            if ($Verbose -eq 'verbose'){Write-Verbose "AssemblyName used as PackageId: $projectId"}
                        } else {
                            $projectId = $projFile.BaseName
                            if ($Verbose -eq 'verbose'){Write-Verbose "Using csproj base name as PackageId: $projectId"}
                        }
                    }
                } catch {
                    if ($Verbose -eq 'verbose'){Write-Verbose "Failed reading csproj '$($projFile.FullName)': $_"}
                    $projectId = $projFile.BaseName
                }
                $badge = "[![Nuget.org](https://img.shields.io/nuget/dt/$($projectId)?label=$($projectId))](https://www.nuget.org/packages/$($projectId))"
                if ($Verbose -eq 'verbose'){Write-Verbose "Generated NuGet badge for package: $projectId"}
            } else {
                if ($Verbose -eq 'verbose'){Write-Verbose "No .psd1 or .csproj found for '$p'"}
            }
        }

        # Fallback to Directory.Build.props (shared PackageId) if still no project ID
        if (-not $projectId -and $Props -and $Props.Project.PropertyGroup.PackageId) {
            $projectId = $Props.Project.PropertyGroup.PackageId
            $badge = "[![Nuget.org](https://img.shields.io/nuget/dt/$($projectId)?label=$($projectId))](https://www.nuget.org/packages/$($projectId))"
            if ($Verbose -eq 'verbose'){Write-Verbose "Using PackageId from Directory.Build.props: $projectId"}
        }

        # Final fallback: project name itself (assume NuGet)
        if (-not $projectId) {
            $projectId = $p
            $badge = "[![Nuget.org](https://img.shields.io/nuget/dt/$($projectId)?label=$($projectId))](https://www.nuget.org/packages/$($projectId))"
            if ($Verbose -eq 'verbose'){Write-Verbose "Falling back to project name as NuGet PackageId: $projectId"}
        }

        if ($badge) {
            $GalleryBadges.Add($badge)
        }
    }

    # --- Build other badges / table -------------------------------------------------
    $readMePath = Join-Path -Path $RootPath -ChildPath "README.md"
    if (-not (Test-Path $readMePath)) {
        # create an empty file so Set-Content works without error
        New-Item -ItemType File -Path $readMePath -Force | Out-Null
        if ($Verbose -eq 'verbose'){Write-Verbose "Created README.md at $readMePath"}
    }

    $TableHeaders = "| Latest Version | Gallery | Issues | Testing | License | Discord |"
    $Columns      = "|-----------------|-----------------|----------------|----------------|----------------|----------------|"
    $VersionBadge = "[![Latest Version](https://img.shields.io/github/v/tag/$GithubOwner/$ProjectName)](https://github.com/$GithubRepo/tags)"
    $IssueBadge   = "[![GitHub issues](https://img.shields.io/github/issues/$GithubOwner/$ProjectName)](https://github.com/$GithubRepo/issues)"
    $TestingBadge = "[![Merge Test Workflow](https://github.com/$GithubRepo/actions/workflows/test.yml/badge.svg)](https://github.com/$GithubRepo/actions/workflows/test.yml)"
    $LicenseBadge = "[![GitHub license](https://img.shields.io/github/license/$GithubOwner/$ProjectName)](https://github.com/$GithubRepo/blob/master/LICENSE)"
    $DiscordBadge = "[![Discord Server](https://assets-global.website-files.com/6257adef93867e50d84d30e2/636e0b5493894cf60b300587_full_logo_white_RGB.svg)](https://discord.com/channels/1044305359021555793/1044305781627035811)"

    $GalleryBadge = ($GalleryBadges -join '<br/>')

    Set-Content -Path $readMePath -Value $TableHeaders
    Add-Content -Path $readMePath -Value $Columns
    Add-Content -Path $readMePath -Value "| $VersionBadge | $GalleryBadge | $IssueBadge | $TestingBadge | $LicenseBadge | $DiscordBadge |"

    # --- Optional: include a project-specific markdown file (case-insensitive) -----
    if ($Verbose -eq 'verbose'){Write-Verbose "Searching for markdown matching '$ProjectName.md' (case-insensitive)..."}
    $ProjectMarkdownFile = Get-ChildItem -Path $RootPath -Recurse -Filter "*.md" |
        Where-Object { $_.Name -ieq "$ProjectName.md" } |
        Select-Object -First 1

    if ($ProjectMarkdownFile) {
        if ($Verbose -eq 'verbose'){Write-Verbose "Appending content from $($ProjectMarkdownFile.FullName)"}
        Get-Content -Path $ProjectMarkdownFile.FullName | Out-File $readMePath -Append
    } else {
        if ($Verbose -eq 'verbose'){Write-Verbose "No matching markdown file found for '$ProjectName.md'. Skipping."}
    }

} catch {
    Write-Host "Error: $_"
    Write-Host "Listing markdown files under $RootPath for troubleshooting:"
    Get-ChildItem -Path $RootPath -Recurse -Filter "*.md" | ForEach-Object {
        Write-Host " - $($_.FullName)"
    }
    throw
}
