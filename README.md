# Update README with Badges

This is a custom GitHub Action that automatically updates the `README.md` file with badges for your projects. It supports both .NET projects (NuGet Gallery) and PowerShell modules (PowerShell Gallery) with auto-detection based on project files.

## Features

- **Auto-Detection**: Automatically detects project type based on file extensions
  - `.psd1` files → PowerShell Gallery badges
  - `.csproj` files → NuGet badges
- **Multi-Project Support**: Handle multiple projects in one repository
- **Smart Badge Generation**: Creates appropriate download/version badges for each platform
- **Custom Documentation**: Appends project-specific markdown content

## Requirements

⚠️ **Important**: This action requires the repository to be checked out before use. Always include `actions/checkout` with `fetch-depth: 0` in your workflow before using this action.

```yaml
- name: Checkout repository
  uses: actions/checkout@v4
  with:
    fetch-depth: 0  # Required for git operations
    token: ${{ secrets.GITHUB_TOKEN }}
```

## Inputs

- `project_name` (required): The base name of your primary project (without file extension)
- `project_names` (optional): List of additional project names for multi-project repositories (comma-separated or JSON array)
- `github_owner` (optional): The GitHub repository owner. Defaults to the repository owner where the action is being run
- `github_repo` (optional): The GitHub repository name. Defaults to the repository name where the action is being run
- `verbose` (optional): Enable detailed logging during execution. Defaults to `false`

## Outputs

The action generates a badge table in your `README.md` with:

- **Latest Version**: GitHub tag-based version badge
- **Gallery**: Download count from NuGet/PowerShell Gallery (auto-detected)
- **Issues**: GitHub issues count
- **Testing**: GitHub Actions workflow status
- **License**: GitHub license badge
- **Discord**: Custom Discord server badge

## Usage Examples

### Single PowerShell Module

For a repository with a PowerShell module:

```bash
MyRepo/
├── MyModule/
│   ├── MyModule.psd1    # PowerShell manifest
│   └── MyModule.psm1    # PowerShell module
└── README.md
```

```yaml
- name: Update README with badges
  uses: mod-posh/UpdateReadme@main
  with:
    project_name: "MyModule"
```

### Single .NET Project

For a repository with a .NET project:

```bash
MyRepo/
├── src/
│   └── MyLibrary.csproj
└── README.md
```

```yaml
- name: Update README with badges
  uses: mod-posh/UpdateReadme@main
  with:
    project_name: "MyLibrary"
```

### Complex PowerShell Module Structure

For modules with naming conventions like yours:

```bash
AdoMetrics/                    # Repository root
├── AdoMetrics/               # Module subfolder
│   ├── ModPosh.AdoMetrics.psd1  # Manifest file
│   └── ModPosh.AdoMetrics.psm1  # Module file
└── README.md
```

```yaml
- name: Update README with badges
  uses: mod-posh/UpdateReadme@main
  with:
    project_name: "ModPosh.AdoMetrics"  # Use the .psd1 filename (without extension)
```

### Multiple Projects (Mixed Types)

For repositories containing both PowerShell modules and .NET projects:

```yaml
- name: Update README with badges
  uses: mod-posh/UpdateReadme@main
  with:
    project_name: "MainProject"
    project_names: "MyPSModule,MyLibrary,AnotherModule"  # CSV format
```

Or using JSON array format:

```yaml
- name: Update README with badges
  uses: mod-posh/UpdateReadme@main
  with:
    project_name: "MainProject"
    project_names: '["MyPSModule", "MyLibrary", "AnotherModule"]'  # JSON format
```

### With Custom Documentation

Create a markdown file named `{project_name}.md` to include project-specific documentation:

```bash
MyRepo/
├── MyModule.psd1
├── MyModule.md     # This content will be appended to README
└── README.md       # Generated badges + MyModule.md content
```

### Complete Workflow Example

Below is a complete workflow example:

```yaml
# .github/workflows/update-readme.yml
name: Update README with Badges

on:
  push:
    branches:
      - main
  release:
    types: [published]

jobs:
  update-readme:
    runs-on: ubuntu-latest
    permissions:
      contents: write  # Required for pushing changes back

    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0  # Required for git operations
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Update README with badges
        uses: mod-posh/UpdateReadme@main
        with:
          project_name: "ModPosh.AdoMetrics"
          verbose: true
```

## How It Works

1. **Project Detection**: The action searches recursively for project files
   - Looks for `{project_name}.psd1` → PowerShell Gallery badge
   - Looks for `{project_name}.csproj` → NuGet badge

2. **Badge Generation**: Creates appropriate badges based on detected project type
   - PowerShell Gallery: `https://img.shields.io/powershellgallery/dt/{ModuleName}`
   - NuGet: `https://img.shields.io/nuget/dt/{PackageId}`

3. **Content Assembly**:
   - Generates badge table
   - Appends content from `{project_name}.md` if it exists
   - Commits changes back to repository

## Notes

- **File Naming**: Use the exact filename (without extension) as your `project_name`
- **Recursive Search**: The action searches subdirectories for project files
- **Module Names**: For PowerShell modules, the module name is extracted from the `.psd1` manifest
- **Package IDs**: For .NET projects, Package ID is read from the `.csproj` file
- **Permissions**: Ensure your workflow has `contents: write` permission to commit changes

## Troubleshooting

Enable verbose logging to see which files are found and what badges are generated:

```yaml
with:
  project_name: "YourProject"
  verbose: true
```

1. **Checkout the Repository**: The first step checks out the repository to access the `README.md` file.

2. **Run the Custom Action**: The `UpdateReadme` action updates the `README.md` file by adding or modifying the badges. It takes the `project_name` as input and defaults to the repository's `owner` and `name`.

3. **Commit the README.md to the Repository**: The updated `README.md` is moved back into the repository, and then a commit is made with the updated file, pushing the changes back to the repository.

### Key Points

- **Flexibility**: The GitHub owner and repo inputs default to the current repository’s values, so users don’t need to specify them unless they are running the action for another repository.
- **Committing Changes**: After downloading the artifact, the workflow adds the `README.md` to the repository and commits the changes.
