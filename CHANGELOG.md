# Changelog

Russian version: [CHANGELOG.ru.md](CHANGELOG.ru.md)

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- **Push All and Check All on the Overview.** With many pairs you no longer
  open each one to run it. Both buttons queue every pair, and the pairs run one
  at a time through the same queue as a single click, with the same journal
  entries and safety checks. Push All skips Auto-Pull pairs, since Yandex is
  their source, and pairs that are already running.

### Fixed

- **"Keep local" in the issue review recreated a folder on Yandex that had just
  been deleted.** A folder name with letters like «й» can be stored in two Unicode
  forms that look identical. Swift treats them as the same name and Yandex does
  not. The review took its paths from the stored snapshot of the last sync, so
  after a duplicate folder was removed on Yandex, «Keep local» uploaded straight
  back into it. Decisions now follow the same rule as sync. A folder that already
  exists on Yandex is written under its Yandex spelling. A file Yandex does not
  have gets the name it has on disk. This covers «Keep local», «Keep remote» and
  «Keep both».
- **After a network outage, scheduled sync stopped for good.** Any failed run
  put the pair into the alarm state, and alarm pairs were left out of the
  schedule until someone pressed Push by hand. After one DNS outage, a pair
  stayed unsynced for almost a day while its card still showed a "Next sync"
  time. Failures caused only by the network now clear on their own: connection
  refused or reset, host not found, timeout. The pair still shows the error,
  and the schedule tries again at the pair's normal interval. You get one
  notification per outage instead of one per attempt. Other failures, like an
  expired token or duplicate folders, still wait for you.
- **"Keep remote" deleted local files without asking.** For a file that is gone
  from Yandex, "Keep remote" means "delete it here too", and the app did that
  straight away, bypassing the Trash. When a folder was removed on Yandex,
  dozens of local files could go in one click. "Apply decisions" now asks
  first and says how many local files will be deleted, and how many files lose
  local edits to the Yandex version. Just taking a newer version from Yandex,
  with no local edits, still applies without a prompt.

## 0.1.3 — 2026-11-20

### Fixed

- **Sync stopped with `410 - GoneError`, and logging in again did not help.**
  Since October 2026 Yandex refuses file operations from rclone's built-in OAuth
  app, while still answering the disk-size request — so the remote looks
  connected and only the runs fail. The connect and «Reconnect account» commands
  the app copies now run the bundled `connect_yandex.py`, which connects the
  remote through a Yandex OAuth app you register yourself, and rclone keeps
  refreshing the token through that app. Step-by-step guide with screenshots:
  [`docs/yandex-oauth-app.md`](docs/yandex-oauth-app.md).
- **MD5 hashes were never read, so any new modification time looked like an
  edit.** rclone prints the hash key as `md5`; the app looked for `MD5`, found
  nothing, and compared files by size and mtime only. A re-upload that left the
  bytes intact could block push on every file it touched. Hashes are now read,
  and matching content no longer counts as a change.
- **The folder button next to a pair's local path did nothing after the folder
  was moved, and the pair kept failing.** The pair only remembered the old
  path, and the app never looked at the folder bookmark it stores. The app now
  checks every pair's local folder when it starts, again when you open the
  pair, and after you save it. A missing or moved folder gets a warning sign in
  the pair list and on the pair card. If the folder moved, the card shows its
  new location with «Use new path»; if it is gone, it offers «Choose folder
  again». The folder button shows a «Path not found» alert instead of staying
  silent. Push, Pull and Check — manual and scheduled — are skipped with a clear
  journal entry rather than running rclone into `directory not found`. A folder
  the app merely has no permission to read is never reported as missing.
- **Push stayed blocked by dozens of "changed on Yandex" files that had not
  changed.** A re-upload gives a file a new modification time on Yandex while
  its bytes stay the same, and the conflict planner treated any mtime change as
  an edit. When both sides report an MD5, the hash now decides; matching bytes
  are no longer a conflict.
- **"Keep both" could stop halfway and leave the local file renamed.** It
  renames the local file, uploads it, then downloads the Yandex copy; when the
  download failed, nothing was undone. A failed step now rolls back the ones
  before it, and the conflict copy no longer lands in the wrong folder when the
  app is started from a directory other than `/`.
- **The review window's "Cancel" button did not cancel anything.** Decisions
  already applied stay applied; the button only closes the window, so it is
  now called "Close".
- **A failed run showed raw rclone output as its headline.** The journal said
  things like `rclone exited with code 3: … directory not found`, or
  `Scheduled Push to Yandex failed: … Duplicate directory found in destination -
  ignoring`, and nothing told you what was wrong or what to do. The app now
  recognises the known causes and writes one plain line plus a «What to do»
  paragraph at the top of the details: a blocked rclone OAuth app (`410
  GoneError`), an expired Yandex token, a missing local folder, a missing Yandex
  folder, and two Yandex folders whose names look identical but differ in Unicode
  normalization (macOS writes NFD, other clients NFC, and rclone ignores one of
  them). That last case is also checked up front when the remote listing is
  taken, so the run stops with the folder named instead of syncing into the wrong
  one. The raw rclone output stays below the advice. A failed «apply decisions»
  now names the file and the chosen action.

## 0.1.2 — 2026-09-01

Every entry here is one bug. The first one froze the whole app, and the rest are
things it said or did while frozen.

### Fixed

- **Sync could stop for good, with no sign anything was wrong.** Waiting for
  rclone to exit used `Process.waitUntilExit()`, which drives the run loop of
  whichever thread calls it while the child's death is reported to the thread
  that launched it. Under Swift Concurrency those are different threads often
  enough, and the wait then never returns. Because every manual and scheduled
  operation runs through one serial queue, a single stuck wait stopped
  synchronising for every pair — one machine sat idle for two weeks. The app now
  waits through `terminationHandler`, and the blocking pipe reads no longer
  occupy threads Swift Concurrency needs.
- **Cyrillic output went missing from the Live monitor.** Each chunk read from
  the pipe was decoded on its own, so a read boundary landing mid-character
  dropped the entire chunk. Measured on a 98,304-character line, 30,248
  characters arrived. Output is now decoded a line at a time.
- **The journal said a run was in progress while it was still queued.** The
  entry is written when the run is requested, which can be long before the queue
  lets it start. It now says queued, and is rewritten when the run actually
  begins.
- **An interrupted run that never started warned about files it never touched.**
  Quitting the app turned any in-flight entry into "the result is unknown, some
  files may already have been transferred, run a Check". For a run abandoned in
  the queue rclone was never launched and nothing moved, so it now says so
  plainly instead of sending you to look for damage that cannot exist.
- **Menu bar quick actions could queue the same pair repeatedly.** The detail
  pane disables its buttons during a run; the menu bar did not, so three clicks
  meant three full runs of the same pair.
- **A hover tip grew into a window-tall empty panel** instead of sizing to its
  text.
- **One action, two spellings.** The manual action said "Pull from Yandex", the
  scheduled one "Pull From Yandex".

## 0.1.1 — 2026-08-13

### Fixed

- **Starting at login left the app unreachable.** A login-item launch creates no
  window, and everything the app set up on first appearance hung off that window
  — so it came up with no menu bar icon, no background syncing, and no way to
  open it. It now comes up in the menu bar, and opening a window from there
  brings the Dock icon back.

## 0.1.0 — 2026-08-12

First public release.
