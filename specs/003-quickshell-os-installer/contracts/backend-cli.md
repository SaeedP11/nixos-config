# Contract: `installer-backend` CLI

Run as root (`sudo`). Success: exit 0, JSON on stdout. Failure: non-zero, `{ "error": { "code", "message" } }` on stdout. All commands accept `--test` (restrict to the device in `$INSTALLER_TEST_DISK`; sets `testMode:true` in outputs).

| Command | Input | Output |
|---|---|---|
| `catalog` | — | Catalog (hosts, apps, sizes) |
| `disks` | — | `{ firmware: "uefi"\|"bios", disks: DiskInfo[] }` |
| `net-check` | — | `{ online: bool, detail }` |
| `plan` | InstallPlan JSON on stdin | `{ valid, problems[], summary: DestructiveSummary, minDiskBytes, estimatedInstallBytes }` |
| `apply [--resume]` | InstallPlan JSON on stdin + `confirmToken` field | stream of events (below); final `done` or `error` |
| `cleanup` | — | `{ unmounted[], closed[] }` — safe teardown of `/mnt` and mappers |
| `status` | — | `state.json` contents (phases) |

## Rules
- `apply` MUST NOT write to any device unless `confirmToken` equals the freshly computed one (exit code 3, `code:"stale-plan"` otherwise).
- Passwords/passphrases are read from the plan on stdin only, written to 0600 tmpfs files, and never logged.
- SIGTERM → cleanup, then final event `cancelled` with `diskState`.

## Event stream (apply), one JSON object per line
```json
{"t":"phase","id":"format","state":"running"}
{"t":"progress","pct":42}
{"t":"log","phase":"install","line":"copying path ..."}
{"t":"error","phase":"install","code":"network","message":"…","retryable":true}
{"t":"done","logPath":"/mnt/etc/nixos/install/install.log"}
{"t":"cancelled","diskState":"formatted"}
```
`log` events are flushed per line (SC-006). Secrets are redacted before emission.
