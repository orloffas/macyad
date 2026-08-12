# Security policy

## Reporting a vulnerability

Please do not open a public issue.

Use [private vulnerability reporting](https://github.com/orloffas/macyad/security/advisories/new) instead. It is the fastest route and keeps the details out of public view until there is a fix.

Expect a first reply within a week. This is a spare-time project with one maintainer, so please read that as an honest estimate rather than an SLA.

## What is in scope

MacYaD is a front end for `rclone`. The interesting surface is small but real:

- the app-managed `rclone.conf`, which holds your remote tokens
- what MacYaD passes to `rclone` — arguments, `--exclude-from` files, config paths
- the security-scoped bookmarks used to keep access to your folders
- the exported configuration file, which is meant to carry **no** credentials
- the state directory under `~/Library/Application Support/MacYaD/`

Anything that makes the app run an unexpected command, leak a token into a log, journal entry or export, or write outside the folders it was granted is in scope.

## What is not

- Vulnerabilities in [`rclone`](https://github.com/rclone/rclone) itself — report those to that project.
- Anything about Yandex Disk as a service, its API or its terms.
- The absence of notarization, and the Gatekeeper warning that follows from it. Builds are self-signed; that is a documented property of this project, not a defect.
- The app not being sandboxed. It launches an external binary and works with user-selected folders anywhere on disk; both are incompatible with the sandbox.

## Supported versions

The latest commit on `main`. There are no maintained release branches.
