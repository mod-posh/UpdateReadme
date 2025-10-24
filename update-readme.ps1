param (
    [string]$ProjectName,
    [string]$ProjectNames,   # CSV or JSON array string
    [string]$RootPath,
    [string]$GithubOwner,
    [string]$GithubRepo,
    [switch]$Verbose
)

# Verbose plumbing
$VerbosePreference = if ($Verbose) { 'Continue' } else { 'SilentlyContinue' }
Write-Verbose "ProjectName: $ProjectName"
Write-Verbose "RootPath: $RootPath"
Write-Verbose "GithubOwner: $GithubOwner"
Write-Verbose "GithubRepo: $GithubRepo"
Write-Verbose "ProjectNames (raw): $ProjectNames"

try {
    # --- Parse multi-project list ---------------------------------------------------
    [string[]]$ResolvedProjects = @()
    if ($ProjectNames) {
        $trimmed = $ProjectNames.Trim()
        if ($trimmed.StartsWith('[')) {
            try {
                $ResolvedProjects = (ConvertFrom-Json -InputObject $trimmed) | ForEach-Object { $_.ToString().Trim() } | Where-Object { $_ }
                Write-Verbose "Parsed ProjectNames from JSON: $($ResolvedProjects -join ', ')"
            } catch {
                Write-Verbose "Failed to parse JSON ProjectNames; will try CSV. Error: $_"
            }
        }
        if (-not $ResolvedProjects -and $trimmed) {
            $ResolvedProjects = $trimmed -split '\s*,\s*' | Where-Object { $_ }
            Write-Verbose "Parsed ProjectNames from CSV: $($ResolvedProjects -join ', ')"
        }
    }
    if (-not $ResolvedProjects -or $ResolvedProjects.Count -eq 0) {
        $ResolvedProjects = @($ProjectName)
        Write-Verbose "No multi-project list provided; using ProjectName for NuGet badge: $ProjectName"
    }

    # --- Try Directory.Build.props once (shared values) -----------------------------
    [xml]$Props = $null
    $BuildPropsPath = Join-Path -Path $RootPath -ChildPath "Directory.Build.props"
    if (Test-Path $BuildPropsPath) {
        try {
            $Props = [xml](Get-Content $BuildPropsPath)
            Write-Verbose "Loaded Directory.Build.props: $BuildPropsPath"
        } catch {
            Write-Verbose "Failed to parse Directory.Build.props: $_"
        }
    } else {
        Write-Verbose "Directory.Build.props not found at root."
    }

    # --- Resolve NuGet package IDs for each project (no functions) ------------------
    $NugetBadges = New-Object System.Collections.Generic.List[string]
    foreach ($p in $ResolvedProjects) {
        Write-Verbose "Resolving PackageId for project '$p'..."

        $pkgId = $null

        # Prefer specific project .csproj if present
        $projFile = Get-ChildItem -Path $RootPath -Recurse -Filter "$p.csproj" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($projFile) {
            Write-Verbose "Found csproj: $($projFile.FullName)"
            try {
                $projXml = [xml](Get-Content -Path $projFile.FullName)
                $pkgId = $projXml.Project.PropertyGroup.PackageId
                if ($pkgId) {
                    Write-Verbose "PackageId from csproj: $pkgId"
                } else {
                    $asm = $projXml.Project.PropertyGroup.AssemblyName
                    if ($asm) {
                        $pkgId = $asm
                        Write-Verbose "AssemblyName used as PackageId: $pkgId"
                    } else {
                        $pkgId = $projFile.BaseName
                        Write-Verbose "Using csproj base name as PackageId: $pkgId"
                    }
                }
            } catch {
                Write-Verbose "Failed reading csproj '$($projFile.FullName)': $_"
            }
        } else {
            Write-Verbose "No csproj found matching '$p.csproj'"
        }

        # Fallback to Directory.Build.props (shared PackageId) if still empty
        if (-not $pkgId -and $Props -and $Props.Project.PropertyGroup.PackageId) {
            $pkgId = $Props.Project.PropertyGroup.PackageId
            Write-Verbose "Using PackageId from Directory.Build.props: $pkgId"
        }

        # Final fallback: project name itself
        if (-not $pkgId) {
            $pkgId = $p
            Write-Verbose "Falling back to project name as PackageId: $pkgId"
        }

        $NugetBadges.Add("[![Nuget.org](https://img.shields.io/nuget/dt/$($pkgId)?label=$($pkgId))](https://www.nuget.org/packages/$($pkgId))")
    }

    # --- Build other badges / table -------------------------------------------------
    $readMePath = Join-Path -Path $RootPath -ChildPath "README.md"
    if (-not (Test-Path $readMePath)) {
        # create an empty file so Set-Content works without error
        New-Item -ItemType File -Path $readMePath -Force | Out-Null
        Write-Verbose "Created README.md at $readMePath"
    }

    $TableHeaders = "| Latest Version | Nuget.org | Issues | Testing | License | Discord |"
    $Columns      = "|-----------------|-----------------|----------------|----------------|----------------|----------------|"
    $VersionBadge = "[![Latest Version](https://img.shields.io/github/v/tag/$GithubOwner/$ProjectName)](https://github.com/$GithubRepo/tags)"
    $IssueBadge   = "[![GitHub issues](https://img.shields.io/github/issues/$GithubOwner/$ProjectName)](https://github.com/$GithubRepo/issues)"
    $TestingBadge = "[![Merge Test Workflow](https://github.com/$GithubRepo/actions/workflows/test.yml/badge.svg)](https://github.com/$GithubRepo/actions/workflows/test.yml)"
    $LicenseBadge = "[![GitHub license](https://img.shields.io/github/license/$GithubOwner/$ProjectName)](https://github.com/$GithubRepo/blob/master/LICENSE)"
    $DiscordBadge = "[![Discord Server](https://assets-global.website-files.com/6257adef93867e50d84d30e2/636e0b5493894cf60b300587_full_logo_white_RGB.svg)](https://discord.com/channels/1044305359021555793/1044305781627035811)"

    $GalleryBadge = ($NugetBadges -join '<br/>')

    Set-Content -Path $readMePath -Value $TableHeaders
    Add-Content -Path $readMePath -Value $Columns
    Add-Content -Path $readMePath -Value "| $VersionBadge | $GalleryBadge | $IssueBadge | $TestingBadge | $LicenseBadge | $DiscordBadge |"

    # --- Optional: include a project-specific markdown file (case-insensitive) -----
    Write-Verbose "Searching for markdown matching '$ProjectName.md' (case-insensitive)..."
    $ProjectMarkdownFile = Get-ChildItem -Path $RootPath -Recurse -Filter "*.md" |
        Where-Object { $_.Name -ieq "$ProjectName.md" } |
        Select-Object -First 1

    if ($ProjectMarkdownFile) {
        Write-Verbose "Appending content from $($ProjectMarkdownFile.FullName)"
        Get-Content -Path $ProjectMarkdownFile.FullName | Out-File $readMePath -Append
    } else {
        Write-Verbose "No matching markdown file found for '$ProjectName.md'. Skipping."
    }

} catch {
    Write-Host "Error: $_"
    Write-Host "Listing markdown files under $RootPath for troubleshooting:"
    Get-ChildItem -Path $RootPath -Recurse -Filter "*.md" | ForEach-Object {
        Write-Host " - $($_.FullName)"
    }
    throw
}
