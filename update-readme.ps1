param (
    [string]$ProjectName,
    [string]$RootPath,
    [string]$GithubOwner,
    [string]$GithubRepo,
    [switch]$Verbose
)

# Output variables if -Verbose is passed
if ($Verbose) {
    Write-Host "ProjectName: $ProjectName"
    Write-Host "RootPath: $RootPath"
    Write-Host "GithubOwner: $GithubOwner"
    Write-Host "GithubRepo: $GithubRepo"
}

try {
    # Step 1: Try Directory.Build.props first
    # Step 2: Fallback to <ProjectName>.csproj if needed
    # Step 3: Fail if still no PackageId
    $PackageId = $null
    $BuildPropsPath = Join-Path -Path $RootPath -ChildPath "Directory.Build.props"
    if (Test-Path $BuildPropsPath) {
        Write-Host "Attempting to read PackageId from Directory.Build.props"
        try {
            $Props = [xml](Get-Content $BuildPropsPath)
            $PackageId = $Props.Project.PropertyGroup.PackageId
            if ($PackageId) {
                Write-Host "Found PackageId in Directory.Build.props: $PackageId"
            } else {
                Write-Host "Directory.Build.props does not contain a PackageId."
            }
        } catch {
            Write-Host "Failed to parse Directory.Build.props: $_"
        }
    } else {
        Write-Host "Directory.Build.props not found at root."
    }
    if (-not $PackageId) {
        Write-Host "Falling back to search for $ProjectName.csproj"
        try {
            $ProjectFile = Get-ChildItem -Path $RootPath -Recurse -Filter "$ProjectName.csproj" -ErrorAction Stop | Select-Object -First 1

            if ($ProjectFile) {
                Write-Host "Found project file: $($ProjectFile.FullName)"
                $ProjectXml = [xml](Get-Content -Path $ProjectFile.FullName)
                $PackageId = $ProjectXml.Project.PropertyGroup.PackageId
                if ($PackageId) {
                    Write-Host "Found PackageId in $($ProjectFile.Name): $PackageId"
                } else {
                    Write-Host "PackageId not found in $($ProjectFile.Name)"
                }
            } else {
                Write-Host "No matching .csproj found."
            }
        } catch {
            Write-Host "Error locating .csproj: $_"
        }
    }
    if (-not $PackageId) {
        throw "Unable to determine PackageId from Directory.Build.props or $ProjectName.csproj"
    }
    if ($Verbose) {
        Write-Host "PackageId: $($PackageId)"
    }

    # Define path to README file
    $readMe = Get-Item -Path "$($RootPath)/README.md"

    # Create badges and table content
    $TableHeaders = "| Latest Version | Nuget.org | Issues | Testing | License | Discord |"
    $Columns = "|-----------------|-----------------|----------------|----------------|----------------|----------------|"
    $VersionBadge = "[![Latest Version](https://img.shields.io/github/v/tag/$($GithubOwner)/$($ProjectName))](https://github.com/$($GithubRepo)/tags)"
    $GalleryBadge = "[![Nuget.org](https://img.shields.io/nuget/dt/$($PackageId))](https://www.nuget.org/packages/$($PackageId))"
    $IssueBadge = "[![GitHub issues](https://img.shields.io/github/issues/$($GithubOwner)/$($ProjectName))](https://github.com/$($GithubRepo)/issues)"
    $TestingBadge = "[![Merge Test Workflow](https://github.com/$($GithubRepo)/actions/workflows/test.yml/badge.svg)](https://github.com/$($GithubRepo)/actions/workflows/test.yml)"
    $LicenseBadge = "[![GitHub license](https://img.shields.io/github/license/$($GithubOwner)/$($ProjectName))](https://github.com/$($GithubRepo)/blob/master/LICENSE)"
    $DiscordBadge = "[![Discord Server](https://assets-global.website-files.com/6257adef93867e50d84d30e2/636e0b5493894cf60b300587_full_logo_white_RGB.svg)](https://discord.com/channels/1044305359021555793/1044305781627035811)"

    # Write content to README.md
    Write-Output $TableHeaders | Out-File $readMe.FullName -Force
    Write-Output $Columns | Out-File $readMe.FullName -Append
    Write-Output "| $($VersionBadge) | $($GalleryBadge) | $($IssueBadge) | $($TestingBadge) | $($LicenseBadge) | $($DiscordBadge) |" | Out-File $readMe.FullName -Append

    # Case-insensitive search for a markdown file matching the expected name
    Write-Host "Searching for a markdown file matching '$ProjectName.md' (case-insensitive)..."
    $ProjectMarkdownFile = Get-ChildItem -Path $RootPath -Recurse -Filter "*.md" |
        Where-Object { $_.Name -ieq "$ProjectName.md" } |
        Select-Object -First 1

    if ($ProjectMarkdownFile) {
        Write-Host "Appending content from $($ProjectMarkdownFile.FullName)"
        Get-Content -Path $ProjectMarkdownFile.FullName | Out-File $readMe.FullName -Append
    } else {
        Write-Host "Warning: No matching markdown file found for '$ProjectName.md'. Skipping this step."
    }

} catch {
    Write-Host "Error: $_"

    # If an error occurs, list all markdown files in the repo for debugging
    Write-Host "Recursing $RootPath to check available markdown files..."
    Get-ChildItem -Path $RootPath -Recurse -Filter "*.md" | ForEach-Object {
        Write-Host "Found markdown file: $($_.FullName)"
    }

    # Re-throw the error
    throw
}
