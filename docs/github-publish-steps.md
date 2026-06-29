# GitHub Publish Steps

The GitHub CLI is not installed in this environment, so publishing needs either GitHub Desktop, the GitHub website, or `git` with an existing remote.

## Option A: Recommended Paid-App Setup

Create a public GitHub repository under `K-boop-design` that does not contain the source code:

1. Go to GitHub and create a new public repository, for example `code-visualizer-downloads`.
2. Add this repository's `README.md`, `docs/marketing-kit.md`, screenshots, and release notes.
3. Upload the built `.zip` or `.dmg` through GitHub Releases.
4. Keep this source project in a private repository.

## Option B: Publish This Source Repository

Only choose this if you are comfortable making the source visible.

```bash
git init
git add .
git commit -m "Prepare Code Visualizer for GitHub release"
git branch -M main
git remote add origin https://github.com/K-boop-design/code-visualizer.git
git push -u origin main
```

## Option C: Use GitHub Desktop

1. Open GitHub Desktop.
2. Choose `File > Add Local Repository`.
3. Select this folder.
4. Publish repository.
5. Choose private for source code, or public only if you want the code visible.
