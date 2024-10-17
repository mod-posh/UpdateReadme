# Update README with Badges

This is a custom GitHub Action that updates the `README.md` file with badges for a given project. The action automatically generates badges for the latest version, NuGet, GitHub issues, license, and Discord server.

## Inputs

- `project_name` (required): The name of the project being updated.
- `github_owner` (optional): The GitHub repository owner. Defaults to the repository owner where the action is being run.
- `github_repo` (optional): The GitHub repository name. Defaults to the repository name where the action is being run.
- `verbose` (optional): If true, enables verbose output during the action's execution. Defaults to `false`.

## Outputs

This action updates the `README.md` file in the repository and uploads it as an artifact.

## Example Usage

### Basic Example

Below is an example workflow that uses this action to update the `README.md` file, uploads the updated file as an artifact, and then downloads the artifact to the local repository.

```yaml
# .github/workflows/update-readme.yml
name: Update README with Badges

on:
  push:
    branches:
      - main

jobs:
  update-readme:
    runs-on: ubuntu-latest

    steps:
      # Checkout the repository to access README.md
      - name: Checkout repository
        uses: actions/checkout@v3

      # Run the custom action to update README.md with badges
      - name: Update README using custom action
        uses: mod-posh/UpdateReadme@main
        with:
          project_name: "PasswordSafeClient"
          verbose: true

      # Upload the updated README.md as an artifact
      - name: Upload updated README.md as an artifact
        uses: actions/upload-artifact@v3
        with:
          name: updated-readme
          path: README.md

  download-and-save-artifact:
    runs-on: ubuntu-latest
    needs: update-readme

    steps:
      # Download the artifact from the previous job
      - name: Download updated README.md artifact
        uses: actions/download-artifact@v3
        with:
          name: updated-readme

      # Move the downloaded README.md to the repository
      - name: Write the README.md to the repository
        run: |
          mv updated-readme/README.md ./README.md
          git config --global user.name 'GitHub Actions'
          git config --global user.email 'actions@github.com'
          git add README.md
          git commit -m "Update README with badges"
          git push
```

## Workflow Explanation

1. **Checkout the Repository**: The first step checks out the repository to access the `README.md` file.
   
2. **Run the Custom Action**: The `UpdateReadme` action updates the `README.md` file by adding or modifying the badges. It takes the `project_name` as input and defaults to the repository's `owner` and `name`.

3. **Upload the Artifact**: The updated `README.md` is uploaded as an artifact using `actions/upload-artifact`.

4. **Download the Artifact**: In the second job (`download-and-save-artifact`), the updated `README.md` is downloaded using `actions/download-artifact`.

5. **Commit the README.md to the Repository**: The updated `README.md` is moved back into the repository, and then a commit is made with the updated file, pushing the changes back to the repository.


### Key Points:
- **Artifact Handling**: The example workflow demonstrates how to use the action to update the `README.md` and then download the artifact, committing the updated file back to the repository.
- **Flexibility**: The GitHub owner and repo inputs default to the current repository’s values, so users don’t need to specify them unless they are running the action for another repository.
- **Committing Changes**: After downloading the artifact, the workflow adds the `README.md` to the repository and commits the changes.
