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
    # Try to load the project file
    $ProjectPath = "$($RootPath)/$($ProjectName)/$($ProjectName)"
    $Project = [xml](Get-Content -Path $ProjectPath)

    # Extract PackageId
    $PackageId = $Project.Project.PropertyGroup.PackageId
    if ($Verbose) {
      Write-Host "PackageId: $($PackageId)"
    }

    # Define path to README file
    $readMe = Get-Item -Path "$($RootPath)\README.md"

    # Create badges and table content
    $TableHeaders = "| Latest Version | Nuget.org | Issues | License | Discord |"
    $Columns = "|-----------------|----------------|----------------|----------------|----------------|"
    $VersionBadge = "[![Latest Version](https://img.shields.io/github/v/tag/$($GithubOwner)/$($ProjectName))](https://github.com/$($GithubRepo)/tags)"
    $GalleryBadge = "[![Nuget.org](https://img.shields.io/nuget/dt/$($PackageId))](https://www.nuget.org/packages/$($PackageId))"
    $IssueBadge = "[![GitHub issues](https://img.shields.io/github/issues/$($GithubOwner)/$($ProjectName))](https://github.com/$($GithubRepo)/issues)"
    $LicenseBadge = "[![GitHub license](https://img.shields.io/github/license/$($GithubOwner)/$($ProjectName))](https://github.com/$($GithubRepo)/blob/master/LICENSE)"
    $DiscordBadge = "[![Discord Server](https://assets-global.website-files.com/6257adef93867e50d84d30e2/636e0b5493894cf60b300587_full_logo_white_RGB.svg)](https://discord.com/channels/1044305359021555793/1044305781627035811)"

    # Write content to README.md
    Write-Output $TableHeaders | Out-File $readMe.FullName -Force
    Write-Output $Columns | Out-File $readMe.FullName -Append
    Write-Output "| $($VersionBadge) | $($GalleryBadge) | $($IssueBadge) | $($LicenseBadge) | $($DiscordBadge) |" | Out-File $readMe.FullName -Append

    # Append additional content from the project's markdown file
    Get-Content -Path "$($RootPath)/$($ProjectName).md" | Out-File $readMe.FullName -Append

} catch {
    if ($_.Exception -is [System.IO.FileNotFoundException]) {
        Write-Host "Error: File not found - $ProjectPath"
        
        # Recurse the root path to search for the missing file
        Write-Host "Recursing $RootPath to search for the project file..."
        Get-ChildItem -Path $RootPath -Recurse -Filter "$ProjectName.xml" | ForEach-Object {
            Write-Host "Found file: $($_.FullName)"
        }

        # Re-throw the error
        throw
    } else {
        # For any other error, just throw it
        throw
    }
}
