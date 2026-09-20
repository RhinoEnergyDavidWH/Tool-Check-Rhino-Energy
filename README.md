# Rhino Tool Check

Per-team tool checks for Rhino Energy Solutions install teams and O&M teams. Matches the
branding and technical conventions of the wider Rhino Energy Solutions app suite (Equipment
Sign-Out, PPE Management, Safety File Register, Fleet Inspection, Rhino Crash Hub): a single
self-contained `docs/index.html`, hosted on GitHub Pages, with a Supabase backend.

## The architecture — read this bit first

The Android app is a **thin native shell that loads the live GitHub Pages site**, not a
packaged copy of it. `capacitor.config.json` points `server.url` at
`https://rhinoenergydavidwh.github.io/Tool-Check-Rhino-Energy/`. That one setting matters
more than anything else here:

- Editing `docs/index.html` (adding a team, tweaking the checklist, fixing a typo) and
  pushing takes effect on both tablets the next time they open or reload the app — **no
  rebuild, no reinstall.**
- A new APK is only needed when something *native* changes: the app icon/splash, a
  Capacitor plugin, or Android permissions.
- `shell/www/index.html` is a tiny fallback page bundled inside the APK itself — it's the
  only thing shown if a tablet has no signal at all, and it never needs to change.

This came from a hard-won lesson on an earlier Rhino Energy build (the GRV app), where the
APK originally packaged the whole app inside itself: every small content change meant a new
build, a new download, and chasing people to reinstall. Don't undo this by pointing
`webDir` back at `docs/` — it would quietly bring that problem back.

## 1. Push this to your repo

Use `git` from a terminal, or [github.dev](https://github.dev) (press `.` on the repo
page) — **not** GitHub's website "Add file → Upload files" drag-and-drop. That uploader
flattens folder structure and dumps every file into the repo root, which has broken past
Rhino Energy builds by scrambling the project layout.

```
cd Tool-Check-Rhino-Energy      # wherever you cloned https://github.com/RhinoEnergyDavidWH/Tool-Check-Rhino-Energy.git
# copy every file from this package into that folder, then:
git add .
git commit -m "Initial build: Rhino Tool Check"
git push
```

## 2. Turn on GitHub Pages

Repo → **Settings → Pages** → Source: **Deploy from a branch** → Branch: `main`, folder **`/docs`**.
Once it's live it'll be at `https://rhinoenergydavidwh.github.io/Tool-Check-Rhino-Energy/`
— this is the URL both the browser and the APK load, so it needs to be live before the app
is much use.

## 3. Set up Supabase (if you haven't already)

1. Go to [supabase.com](https://supabase.com) → New project.
2. Once it's created, open **SQL Editor → New query**, paste in the contents of
   `supabase/schema.sql`, and run it.
3. New query again, paste in `supabase/seed.sql`, and run it — this loads all 10 teams
   (Team 1–7, O&M Steven, and the generic starting checklists for O&M Tlou and O&M
   Nangamso) with every tool from your spreadsheet.
4. Go to **Settings → API**. You'll need the **Project URL** and the **`anon` public key**.

## 4. Connect the app to Supabase

Open `docs/index.html` in a text editor, find these two lines near the top of the
`<script>` block:

```js
const SUPABASE_URL = "YOUR_SUPABASE_URL";
const SUPABASE_ANON_KEY = "YOUR_SUPABASE_ANON_KEY";
```

Replace them with your project's real values, save, and push. **Don't paste these into a
chat with anyone** — they're safe to keep in this file because they're protected by the
Row Level Security policies in `schema.sql`, not by secrecy, but there's no need to hand
them around either.

Once pushed, reload the GitHub Pages URL — the "not connected yet" screen should be
replaced by the app itself.

## 5. Build the Android APK

The workflow in `.github/workflows/build-apk.yml` runs automatically on every push to
`main` (and can always be run by hand from the **Actions** tab → "Build Android APK" →
**Run workflow**, in case a push ever doesn't trigger one for some reason).

1. GitHub repo → **Actions** tab → open the latest run.
2. Once it finishes (a few minutes), scroll to **Artifacts** and download
   `rhino-tool-check-apk` — a zip containing `rhino-tool-check-<build number>.apk`.
3. Copy that APK onto each Samsung tablet (USB, email to yourself, Google Drive — whatever's
   easiest) and open it there. Android will ask you to allow installing from this source the
   first time; approve it, then install.

You should only need to repeat this the *first* time, and again later only if you add a
Capacitor plugin, change the app icon, or similar — everyday content and UI changes go
live through step 4 alone, per the architecture note above.

This is a **debug** build, which is normal and fine for sideloading onto your own two
tablets — it avoids needing to manage a release signing key for something that's never
going to the Play Store. The build uses a fixed `debug.keystore` (committed in this repo
on purpose — a debug keystore has no security value, its password is the public default
"android") specifically so that every future build still installs cleanly *over* the
previous one on both tablets, rather than Android refusing the install with "App not
installed" because it looks like a different, untrusted app.

**If a build ever fails:** the Actions log view often truncates the actual error. Open the
failed run → the gear icon (top right) → **Download log archive** → look at the last step
before the ones that just say `Evaluating: success() => false` — that's the one that
actually failed, and its full log is in there.

## 6. Add it to the Rhino Crash Hub

Once the Pages URL is live, let Dave know so it can be added to the hub's grid. The
"← Hub" link in the app's own header already points back to it.

## What's inside

```
docs/index.html          the whole app (HTML + CSS + JS, matches the suite's branding) —
                         this is what's served by GitHub Pages AND what the APK loads live
docs/manifest.json       PWA manifest (optional web-install, mirrors the hub's own pattern)
docs/service-worker.js   app-shell caching only — never touches Supabase/API calls
docs/icons/              placeholder PWA icons (browser tab / "add to home screen")
shell/www/index.html     tiny offline-fallback page bundled INSIDE the APK — only shown
                         when a tablet has no signal at all; not the real app
assets/                  source images for the native Android app icon + splash screen
                         (icon-background.png, icon-foreground.png, icon.png, splash.png)
                         — placeholders; swap for the real Rhino Energy logo when ready,
                         keeping artwork inside the centre ~66% of icon-foreground.png so
                         Android's adaptive-icon mask doesn't crop it
debug.keystore           fixed debug signing key (see step 5) — safe to keep committed
supabase/schema.sql      database tables + Row Level Security policies
supabase/seed.sql        all 10 teams and every tool from the 2026 tool-check spreadsheet
capacitor.config.json    Capacitor config — server.url points at the live Pages site;
                         webDir points at the tiny offline fallback, not the real app
package.json             Capacitor + plugin dependencies (npm install, not npm ci — no
                         lockfile is committed, so there's nothing for ci to mismatch)
.github/workflows/       the GitHub Actions job that builds the APK; generates the native
                         Android project fresh each run rather than committing it
```

## Notes on the two teams with generic checklists

O&M Tlou and O&M Nangamso were seeded with a generalised maintenance-team checklist
(based on O&M Steven's kit) rather than a real inventory — use the **Teams & Tools** page
in the app to rename, add, or remove tools until each matches what those teams actually
carry.

---
*This document was developed with the assistance of an AI agent under the direction of qualified RES personnel.*
