# GitHub Actions for Chrome extension release

A complete `.github/workflows/release.yml` that lints, builds, tests, zips, and uploads to Chrome Web Store as a draft on every tag push.

## Required secrets

Set these in **Settings → Secrets and variables → Actions**:

- `CW_EXTENSION_ID`
- `CW_CLIENT_ID`
- `CW_CLIENT_SECRET`
- `CW_REFRESH_TOKEN`

See `oauth-setup.md` for how to obtain them.

## The workflow

```yaml
name: Release

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:
    inputs:
      publish_live:
        description: 'Publish to live store (default: upload as draft only)'
        required: false
        type: boolean
        default: false

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4

      - uses: pnpm/action-setup@v4
        with:
          version: 9

      - uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install
        run: pnpm install --frozen-lockfile

      - name: Lint (TypeScript)
        run: pnpm run lint

      - name: Type check
        run: pnpm run typecheck

      - name: Unit tests
        run: pnpm run test --run

      - name: Build (Chrome)
        run: pnpm run build

      - name: Lint built extension (web-ext)
        run: pnpm dlx web-ext@latest lint --source-dir=.output/chrome-mv3 --self-hosted --no-config-discovery

      - name: Smoke test (Playwright)
        run: |
          pnpm exec playwright install chromium
          EXTENSION_DIR="$(pwd)/.output/chrome-mv3" pnpm exec playwright test --reporter=line

      - name: Zip
        run: pnpm run zip

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: extension-${{ github.ref_name || 'manual' }}
          path: .output/*.zip
          retention-days: 90

      - name: Upload to CWS as draft
        env:
          EXTENSION_ID: ${{ secrets.CW_EXTENSION_ID }}
          CLIENT_ID:    ${{ secrets.CW_CLIENT_ID }}
          CLIENT_SECRET: ${{ secrets.CW_CLIENT_SECRET }}
          REFRESH_TOKEN: ${{ secrets.CW_REFRESH_TOKEN }}
        run: |
          ZIP=$(ls -t .output/*.zip | head -1)
          echo "Uploading $ZIP"
          pnpm dlx chrome-webstore-upload-cli@latest upload \
            --source "$ZIP" \
            --extension-id "$EXTENSION_ID" \
            --client-id "$CLIENT_ID" \
            --client-secret "$CLIENT_SECRET" \
            --refresh-token "$REFRESH_TOKEN"

      - name: Publish live (only on manual dispatch with input)
        if: github.event_name == 'workflow_dispatch' && inputs.publish_live == true
        env:
          EXTENSION_ID: ${{ secrets.CW_EXTENSION_ID }}
          CLIENT_ID:    ${{ secrets.CW_CLIENT_ID }}
          CLIENT_SECRET: ${{ secrets.CW_CLIENT_SECRET }}
          REFRESH_TOKEN: ${{ secrets.CW_REFRESH_TOKEN }}
          CONFIRM_PUBLISH_LIVE: '1'
        run: |
          # chrome-webstore-upload-cli has no separate "publish" command — use
          # --auto-publish on the upload command to push it live.
          ZIP=$(ls -t .output/*.zip | head -1)
          pnpm dlx chrome-webstore-upload-cli@latest upload \
            --source "$ZIP" \
            --extension-id "$EXTENSION_ID" \
            --client-id "$CLIENT_ID" \
            --client-secret "$CLIENT_SECRET" \
            --refresh-token "$REFRESH_TOKEN" \
            --auto-publish

      - name: Create GitHub release
        if: startsWith(github.ref, 'refs/tags/v')
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          ZIP=$(ls -t .output/*.zip | head -1)
          gh release create "${{ github.ref_name }}" "$ZIP" \
            --title "Release ${{ github.ref_name }}" \
            --generate-notes
```

## How it works

- **Tag push** (`v1.2.3`, `v1.2.4`, …) triggers the workflow.
- Lint, type-check, test, build, smoke-test, zip — same as local.
- **Always uploads as a draft.** Default behavior, every tag.
- **Manual `workflow_dispatch`** with `publish_live: true` actually publishes live — a deliberate human step.
- **GitHub release** is auto-created with the zip attached.

## Optional: multi-browser builds

```yaml
strategy:
  matrix:
    browser: [chrome, firefox, edge]
steps:
  - name: Build (${{ matrix.browser }})
    run: pnpm run build -- -b ${{ matrix.browser }}
  - name: Upload artifact (${{ matrix.browser }})
    uses: actions/upload-artifact@v4
    with:
      name: extension-${{ matrix.browser }}-${{ github.ref_name }}
      path: .output/*-${{ matrix.browser }}-*.zip
```

For Firefox, the upload step uses `web-ext sign` instead of `chrome-webstore-upload-cli`. See the `web-ext` docs.

## Optional: preview deploys on PRs

On every PR, build the extension and post a comment with a downloadable artifact link:

```yaml
on:
  pull_request:

jobs:
  preview:
    runs-on: ubuntu-latest
    steps:
      # ... checkout, install, build, zip ...

      - name: Upload PR artifact
        uses: actions/upload-artifact@v4
        with:
          name: extension-pr-${{ github.event.pull_request.number }}
          path: .output/*.zip
          retention-days: 14

      - name: Comment on PR
        uses: actions/github-script@v7
        with:
          script: |
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body: `Preview build: https://github.com/${context.repo.owner}/${context.repo.repo}/actions/runs/${context.runId}`
            });
```

Reviewers can download the artifact, load it unpacked, and test before merging.

## Caching

`pnpm/action-setup` + `actions/setup-node` with `cache: 'pnpm'` already cache the pnpm store. For Playwright browsers:

```yaml
- name: Cache Playwright browsers
  uses: actions/cache@v4
  with:
    path: ~/.cache/ms-playwright
    key: playwright-${{ runner.os }}-${{ hashFiles('**/pnpm-lock.yaml') }}
```

This shaves ~1 minute off each run.

## Don't forget

- **Bump `version` in `manifest.json`** before tagging. CWS rejects duplicate versions.
- **Update CHANGELOG.md** before tagging. Auto-release-notes are nice but a human-written CHANGELOG is better.
- **Tag conventions**: `vMAJOR.MINOR.PATCH`. Don't use prefix `release-` or `r-` — `v*` is the convention everyone expects.

## Failure modes to plan for

- **`web-ext lint` warnings**: by default warnings don't fail the job. If you want to enforce, add `--strict` flag.
- **Playwright flakes**: extend the smoke test's timeout, but don't add retries. Flakes are bugs.
- **CWS upload failure**: usually `VERSION_ALREADY_EXISTS` or `ITEM_NOT_UPDATABLE`. The error message is clear; fix and re-run.
- **Refresh token expired**: re-run `oauth-setup.md` Step 5 and rotate the `CW_REFRESH_TOKEN` secret.

## Workflow security

- Use **branch protection** on `main`. Don't allow direct pushes to main.
- Use **required reviewers** on PRs that change `release.yml` itself.
- Use **environment protection** rules on the secrets — only certain branches/tags can use them.
- The `publish_live` input is a manual gate; consider adding required reviewers for the workflow_dispatch event too.
