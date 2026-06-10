# Releasing Consoled

Two things ship each release, both from **GitHub Releases** (no update server):

| Artifact | For | Where it goes |
|---|---|---|
| `Consoled-<ver>.dmg` | humans downloading manually | attached to the `v<ver>` release |
| `Consoled-<ver>.zip` | Sparkle in-app auto-updates | attached to the `v<ver>` release |
| `appcast.xml` | the update *feed* the app polls | **committed to the repo** (served raw) |

The app reads `appcast.xml` over `https://raw.githubusercontent.com/warrun/consoled/main/appcast.xml`,
sees a newer `<item>`, downloads that item's `.zip` from its release, verifies the EdDSA signature
against the public key baked into the app, and installs it.

---

## Every release (the normal path)

```bash
./scripts/release.sh 1.1.3        # pass the new marketing version
```
That builds + packages everything locally, then **prints** the exact git + `gh` commands. Review them,
then paste:

```bash
git add -A                                   # version bump + appcast.xml
git commit -m "Consoled 1.1.3"
git tag -a v1.1.3 -m "Consoled 1.1.3"
git push origin main
git push origin v1.1.3
gh release create v1.1.3 \
    dist/Consoled-1.1.3.dmg \
    dist/Consoled-1.1.3.zip \
    --title "Consoled 1.1.3" --notes "…"
```

### What each piece does (so you trust it)
- **`release.sh` (local, reversible, no network):**
  1. `MARKETING_VERSION` → the version you passed; `CURRENT_PROJECT_VERSION` → +1. *(Sparkle compares the
     build number to decide "newer", so it must increase every release — the script handles that.)*
  2. Clean `xcodebuild` Release; verifies the built version matches.
  3. Makes the **DMG** (drag-to-Applications) and the **ZIP** (what Sparkle installs).
  4. If Sparkle is set up: `sign_update` the ZIP (EdDSA) and prepend a new `<item>` to `appcast.xml`
     pointing at `…/releases/download/v<ver>/Consoled-<ver>.zip`. If not set up, it skips this and says so.
- **`git commit`** records the version bump **and** the updated `appcast.xml`.
- **`git tag` / `git push … v<ver>`** creates the immutable version marker the release attaches to.
- **`gh release create v<ver> …`** publishes the release and uploads the DMG + ZIP. The committed
  `appcast.xml` already references this release's ZIP URL, so once both are pushed the feed resolves.

> Order matters only slightly: pushing the commit publishes the new `appcast.xml`; the `gh release` makes
> the ZIP URL it points to exist. Do both and users get the update on their next check.

---

## One-time setup (before auto-updates work)

Sparkle is **already integrated** (SPM dependency, an updater + "Check for Updates…" menu item, the
`SUFeedURL`/`SUPublicEDKey` keys in `Consoled-Info.plist`, and `appcast.xml` seeded at the repo root).
The updater stays **inert** until you replace the placeholder key — so two things remain, both yours to run:

1. **Generate signing keys (once):**
   ```bash
   # built once already, so the tool is here:
   ./build/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys
   ```
   It stores the **private key in your Keychain** (never in the repo) and prints a **public key**.
   Paste that public key into `Consoled-Info.plist`, replacing `PLACEHOLDER_run_generate_keys`. Rebuild —
   now the "Check for Updates…" item is live and `release.sh` will sign + write the appcast.
2. **Install the GitHub CLI** and log in (for `gh release create`):
   ```bash
   brew install gh && gh auth login
   ```

> `release.sh` finds `sign_update` automatically (it lives next to `generate_keys` in the resolved
> Sparkle package). Until the placeholder key is replaced, `release.sh` still does versioning + DMG +
> git; it just skips the signing/appcast step.

---

## How the user experiences it
- **First install (DMG):** unsigned/unnotarized, so macOS Gatekeeper blocks the first launch —
  **right-click → Open** once (or `xattr -dr com.apple.quarantine /Applications/Consoled.app`). Put this
  line in every release's notes.
- **After that:** Sparkle checks periodically (and via **Check for Updates…**), prompts when a new version
  exists, and installs it. Sparkle strips the quarantine flag on updates it installs, so the relaunch
  doesn't re-prompt — auto-updates are seamless after the one-time first-launch approval.

## Troubleshooting
- **App won't see updates:** confirm the new `<item>`'s `sparkle:version` (build number) is higher than the
  installed one, and that the raw `appcast.xml` URL returns the new entry (raw caches ~5 min).
- **"Update is improperly signed":** the ZIP was changed after signing, or the `SUPublicEDKey` in the app
  doesn't match the Keychain private key. Re-run `release.sh` to re-sign.
- **`gh: command not found`:** `brew install gh` and `gh auth login`.
