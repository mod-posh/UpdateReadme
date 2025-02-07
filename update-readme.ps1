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
    # Recursively search for the .csproj file
    Write-Host "Searching for .csproj file for project: $ProjectName"
    $ProjectFile = Get-ChildItem -Path $RootPath -Recurse -Filter "$ProjectName.csproj" -ErrorAction Stop | Select-Object -First 1

    if (-not $ProjectFile) {
        throw "Project file not found."
    }

    Write-Host "Found project file: $($ProjectFile.FullName)"

    # Load the .csproj file as XML
    $Project = [xml](Get-Content -Path $ProjectFile.FullName)

    # Extract PackageId
    $PackageId = $Project.Project.PropertyGroup.PackageId
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
