# Contributing

Thanks for looking. This is a small project with one maintainer, so the short version is: open an issue before writing anything large, and expect replies to take days rather than hours.

## Before you start

- **Bugs** go through the [bug report form](https://github.com/orloffas/macyad/issues/new?template=bug_report.yml). It asks for the rclone version, the macOS version and the journal entry, because without those a sync report is unactionable.
- **Questions and setup problems** belong in [Discussions](https://github.com/orloffas/macyad/discussions), not in issues.
- **Security problems** go through [private reporting](https://github.com/orloffas/macyad/security/advisories/new). See [SECURITY.md](SECURITY.md).
- **Large changes** — ask first. A PR that rewrites the sync model will not be merged on its merit alone, because the model is the product.

## What will not be accepted

Not because the idea is bad, but because it contradicts what this app is:

- Automatic two-way sync, or any scheduled run that resolves a conflict on its own.
- Anything that transfers files without the baseline check in front of it.
- Telemetry, analytics, crash reporting to a server, or an auto-updater.
- Vendoring `rclone`, or replacing it with a hand-written Yandex Disk client.

## Setting up

```bash
brew install rclone xcodegen
git clone https://github.com/orloffas/macyad.git
cd macyad
xcodegen generate          # Macyad.xcodeproj is generated, never committed
open Macyad.xcodeproj
```

For a full build-install-run cycle, use `./script/build_and_run.sh`. If you rebuild often, set up the [local signing certificate](docs/local-signing.md) — otherwise macOS asks for folder access again after every build.

## Testing

```bash
./script/test.sh unit      # MacyadCore — what CI runs
./script/test.sh ui        # adds XCUITest; needs an unlocked, awake display
```

Two things worth knowing before you send a PR:

- The unit scheme **does not compile the views**. After touching anything in `Macyad/Views/`, build the app target too: `xcodebuild build -project Macyad.xcodeproj -scheme Macyad -destination 'platform=macOS'`.
- UI tests assert `isHittable`, not just existence. A pane that fails to lay out still has a complete accessibility tree, so existence checks pass on a window that renders blank. This is not paranoia — it is how a real bug survived a green suite.

## Code

- Swift 6, macOS 14 deployment target. Both are set in `project.yml`; edit that, never the generated `.xcodeproj`.
- Every user-facing string goes through `AppCopy` in both English and Russian. `NSLocalizedString` is not used in this codebase.
- Comments explain why, not what. If a line looks strange and is deliberate, say why it is deliberate.
- Each directory has an `AGENTS.md` describing what lives there and the traps specific to it. Read the one next to the code you are changing; update it if your change invalidates it.
- Commit messages and PR descriptions in English.

## Pull requests

`main` is protected: work on a branch and open a PR, including maintainer work. CI runs unit tests and builds the app target; both must pass.

Keep a PR to one thing. Two unrelated fixes are two PRs — they get reviewed faster and revert cleanly.

If your change alters behaviour, update `README.md` **and** `README.ru.md`. They are expected to say the same things; a change to one without the other is an unfinished change.

Final call on scope and design is the maintainer's. If a PR is declined, it is usually about fit rather than quality.
