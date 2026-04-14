# Diplomax CM CI/CD Guide

This repository now includes GitHub Actions workflows for CI, APK builds, releases, and backend image publishing.

## Workflows

- `.github/workflows/diplomax-ci.yml`
  - Trigger: push/PR on `main` when `diplomax_cm/**` changes.
  - Runs:
    - Backend `pytest`
    - Flutter `pub get`, `analyze`, `test` for:
      - `diplomax_student`
      - `diplomax_university`
      - `diplomax_recruiter`

- `.github/workflows/diplomax-apk-build.yml`
  - Trigger: push on `main` for app changes, or manual dispatch.
  - Builds release APKs for all 3 apps and uploads them as workflow artifacts.
  - Uses staging API URL strategy (override-friendly).

- `.github/workflows/diplomax-release-apks.yml`
  - Trigger: tag push matching `v*`.
  - Builds APKs for all 3 apps and publishes them to GitHub Releases.
  - Auto-generates release notes body.

- `.github/workflows/diplomax-backend-image.yml`
  - Trigger: push on `main`/`v*` tag for backend changes, or manual dispatch.
  - Builds and pushes backend image to GHCR.
  - Optionally triggers external deployment webhook if configured.

## Environment Strategy

Flutter API endpoint resolution in workflows:

1. Release workflow (`v*` tags):
   - Uses repository variable `PROD_API_BASE_URL` if set.
   - Fallback: `https://api.diplomax.cm/v1`.

2. APK build workflow (main/manual):
   - Uses manual input `api_base_url` if provided.
   - Else uses repository variable `STAGING_API_BASE_URL` if set.
   - Fallback: `https://staging-api.diplomax.cm/v1`.

Runtime app code already defaults to production endpoint and supports `--dart-define=API_BASE_URL=...` overrides.

## GitHub Secrets and Variables

Set these in repository settings:

### Variables (recommended)
- `PROD_API_BASE_URL` (example: `https://api.diplomax.cm/v1`)
- `STAGING_API_BASE_URL` (example: `https://staging-api.diplomax.cm/v1`)

### Secrets (optional but recommended)
- `BACKEND_DEPLOY_WEBHOOK_URL`
  - If set, backend image workflow calls this URL after successful image push on `main`.

No extra secret is required for GitHub Releases or GHCR publish in this setup because `GITHUB_TOKEN` is used.

## Tag and Version Convention

Recommended release tags:

- Stable: `vMAJOR.MINOR.PATCH` (example: `v2.0.0`)
- Pre-release: `vMAJOR.MINOR.PATCH-rc.N` (example: `v2.1.0-rc.1`)

Workflow behavior:
- Any `v*` tag creates a GitHub Release with APKs.
- Tags containing `-rc`, `-beta`, or `-alpha` are marked as pre-releases.

App semantic versions are still read from each app `pubspec.yaml` `version:` field.

## Artifact Naming Convention

APK artifact names:

- CI build artifacts:
  - `diplomax-{app}-{pubspecVersionSanitized}-{sha7}.apk`
  - Example: `diplomax-student-2.0.0-1-a1b2c3d.apk`

- GitHub Release assets:
  - `diplomax-{app}-{pubspecVersionSanitized}-{tag}.apk`
  - Example: `diplomax-student-2.0.0-1-v2.0.0.apk`

Where `{app}` is one of `student`, `university`, `recruiter`.

## Release Notes Format

Release notes are generated automatically and include:

- Release title with tag
- Included apps list
- API target URL
- APK asset list

If you want a custom changelog style later, replace the notes-generation step in `.github/workflows/diplomax-release-apks.yml`.
