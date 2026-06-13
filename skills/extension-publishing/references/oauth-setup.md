# Chrome Web Store OAuth setup for programmatic publishing

The CWS publish API requires Google OAuth. Setup is one-time but fiddly. Do it once, capture the credentials as GitHub Actions secrets, and forget about it.

## Prerequisites

- A Google account that owns the CWS listing.
- The extension already has a CWS listing (manually submit the first version via the dashboard — the `EXTENSION_ID` only exists after that).

## Step 1: create a Google Cloud project

1. Go to <https://console.cloud.google.com>.
2. Create a new project (or use an existing one). Name it something like `chrome-extension-publish`.

## Step 2: enable the Chrome Web Store API

1. In the project, go to **APIs & Services → Library**.
2. Search for "Chrome Web Store API".
3. Click **Enable**.

## Step 3: configure OAuth consent screen

1. **APIs & Services → OAuth consent screen.**
2. User type: **External** (unless you have a Workspace and prefer Internal).
3. Fill in app name, support email, developer email. Other fields can be minimal.
4. **Scopes**: add `https://www.googleapis.com/auth/chromewebstore`.
5. **Test users**: add your own Google account.
6. Save. You don't need to publish the OAuth consent for personal use; it can stay in "Testing" status (good for 7 days at a time of refresh-token validity, then re-auth) or go through verification for permanent use.

## Step 4: create OAuth 2.0 credentials

1. **APIs & Services → Credentials → Create credentials → OAuth client ID.**
2. Application type: **Desktop app** (this gives you the `urn:ietf:wg:oauth:2.0:oob` redirect URI).
3. Name: `chrome-webstore-cli` or similar.
4. Click **Create**.
5. **Save the `Client ID` and `Client secret` displayed.**

## Step 5: obtain a refresh token

Open this URL in a browser (substitute `YOUR_CLIENT_ID`):

```
https://accounts.google.com/o/oauth2/auth?response_type=code&scope=https://www.googleapis.com/auth/chromewebstore&client_id=YOUR_CLIENT_ID&redirect_uri=urn:ietf:wg:oauth:2.0:oob&prompt=consent&access_type=offline
```

The page may show a "Google hasn't verified this app" warning. Click "Advanced" → "Go to chrome-extension-publish (unsafe)" — it's your app; trust yourself.

Grant access. You'll be redirected to a page showing a **code**. Copy it.

Exchange the code for a refresh token:

```bash
curl -X POST https://oauth2.googleapis.com/token \
  -d code=YOUR_AUTH_CODE \
  -d client_id=YOUR_CLIENT_ID \
  -d client_secret=YOUR_CLIENT_SECRET \
  -d redirect_uri=urn:ietf:wg:oauth:2.0:oob \
  -d grant_type=authorization_code
```

Response includes a `refresh_token` field. **Save that.**

## Step 6: capture all four values

You now have:

- `CLIENT_ID`
- `CLIENT_SECRET`
- `REFRESH_TOKEN`
- `EXTENSION_ID` (from the CWS dashboard URL)

Add them to GitHub Actions secrets (or to your local `.env`, **gitignored**):

| Secret name | Value |
|---|---|
| `CW_CLIENT_ID` | Step 4 output |
| `CW_CLIENT_SECRET` | Step 4 output |
| `CW_REFRESH_TOKEN` | Step 5 output |
| `CW_EXTENSION_ID` | From CWS dashboard |

## Step 7: test with chrome-webstore-upload-cli

v4 reads OAuth credentials from the fixed env vars `CLIENT_ID`, `CLIENT_SECRET`, and `REFRESH_TOKEN` (the v3 `--client-id`/`--client-secret`/`--refresh-token` flags were removed). Map your `CW_*` secrets onto those names for the command:

```bash
CLIENT_ID="$CW_CLIENT_ID" \
CLIENT_SECRET="$CW_CLIENT_SECRET" \
REFRESH_TOKEN="$CW_REFRESH_TOKEN" \
pnpm dlx chrome-webstore-upload-cli@4 upload \
  --source path/to/extension.zip \
  --extension-id "$CW_EXTENSION_ID"
```

Expected output: `Upload successful` and the new version in your CWS dashboard as a draft.

## Important: keep it as a draft

The `upload` subcommand creates a new **draft** version. It does NOT publish. To go live, v4 uses a separate `publish` subcommand (and running the CLI with **no subcommand** would upload AND publish in one shot — avoid that):

```bash
CONFIRM_PUBLISH_LIVE=1 \
CLIENT_ID="$CW_CLIENT_ID" \
CLIENT_SECRET="$CW_CLIENT_SECRET" \
REFRESH_TOKEN="$CW_REFRESH_TOKEN" \
pnpm dlx chrome-webstore-upload-cli@4 publish \
  --extension-id "$CW_EXTENSION_ID"
```

**Default your CI to the `upload` (draft) subcommand.** Make live publish an explicit, separate workflow that requires manual approval. A bad release going live without review is far worse than a draft sitting in the dashboard.

The plugin's PreToolUse hook blocks the `publish` subcommand and bare `chrome-webstore-upload` invocations (both publish live) unless prefixed with `CONFIRM_PUBLISH_LIVE=1`; the `upload` subcommand is always allowed.

## Troubleshooting

### "invalid_grant" / "Token has been expired or revoked"

The refresh token expired. Common causes:

- Your OAuth consent screen is in "Testing" status. Test-mode refresh tokens expire after 7 days. Either:
  - Re-run Step 5 to get a fresh one, OR
  - Publish the OAuth consent (Step 3) to make tokens long-lived.
- You revoked access at <https://myaccount.google.com/permissions>. Re-grant.
- Google detected unusual activity and revoked. Re-grant.

### "ITEM_NOT_FOUND" / "Item not found"

The `EXTENSION_ID` is wrong or the OAuth user doesn't own the extension. Verify in the CWS dashboard.

### "VERSION_ALREADY_EXISTS"

You're uploading a zip whose `manifest.json` version matches an already-uploaded version. Bump `version` in `manifest.json` and rebuild.

### "ITEM_NOT_UPDATABLE"

The previous upload is still being reviewed. Wait until review completes (or rejects) before uploading a new draft.

### Permission denied for `chromewebstore` scope

The OAuth user isn't the owner of the extension, or you forgot to add the `chromewebstore` scope to the consent screen.

## Sharing credentials with a team

These credentials grant publish access. Treat them like prod database passwords:

- ✅ Store in GitHub Actions secrets (encrypted at rest).
- ✅ Rotate when team members leave.
- ❌ Never commit to git, even in private repos.
- ❌ Never share in Slack or email.
- ❌ Never check into `.env` files that aren't gitignored.

For shared publishing, consider a dedicated `release@your-domain.com` Google account, not a personal one. Personal accounts going on vacation or leaving the company shouldn't break releases.

## Renewals and rotation

OAuth credentials don't auto-expire (the refresh token can be revoked, but the client_id/secret don't). However, best practice:

- Rotate the `client_secret` annually.
- Re-run Step 5 after any rotation.
- Update GitHub Actions secrets.

## Alternative: service account (Google Workspace only)

If your org has Google Workspace, you can use a service account instead of a personal OAuth flow. It's more setup but better for orgs. See the `chrome-webstore-upload-cli` README for the service-account guide.

For most teams, the personal-OAuth flow above is simpler and works fine.
