# Changelog

Russian version: [CHANGELOG.ru.md](CHANGELOG.ru.md)

This project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Fixed

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
- **Sync stopped with `410 - GoneError`, and logging in again did not help.**
  Since October 2026 Yandex refuses file operations from rclone's built-in OAuth
  app, while still answering the disk-size request — so the remote looks
  connected and only the runs fail. The connect and «Reconnect account» commands
  the app copies now run the bundled `connect_yandex.py`, which connects the
  remote through a Yandex OAuth app you register yourself, and rclone keeps
  refreshing the token through that app. Step-by-step guide with screenshots:
  [`docs/yandex-oauth-app.md`](docs/yandex-oauth-app.md).

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
