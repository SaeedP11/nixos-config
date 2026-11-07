# Contract: InstallPlan JSON

```json
{
  "locale": { "language": "en_US.UTF-8", "keyboardLayout": "us", "keyboardVariant": "", "timeZone": "Asia/Tehran" },
  "profile": "laptop",
  "hostName": "laptop",
  "user": { "name": "alice", "fullName": "Alice", "password": "<clear, stdin only>" },
  "disk": {
    "mode": "erase",                       
    "target": "/dev/nvme0n1",
    "encryption": { "enabled": true, "passphrase": "<clear, stdin only>" },
    "filesystem": "btrfs",                 
    "swap": { "kind": "file", "sizeGiB": 8 },
    "layout": []                           
  },
  "apps": { "freecad": false, "libreoffice": true, "godot": false, "chrome": true,
            "insomnia": false, "escrcpy": false, "vscode": true, "nordzyCursor": true },
  "confirmToken": "<from plan>"
}
```
- `disk.mode`: `erase` | `alongside` | `manual`.
- `disk.filesystem`: `ext4` | `btrfs`.
- `alongside` adds `{ "shrinkPartition": "/dev/…", "newRootGiB": N, "reuseEsp": "/dev/…" }`.
- `manual.layout[]`: `{ "device"|"create": …, "mountpoint": "/"|"/boot"|"/home"|"swap"|…, "fs": …, "format": bool, "sizeGiB"? }`.
- `apps` keys MUST equal the catalog's app ids; unknown or missing keys are validation problems.
- The plan is never persisted with clear-text secrets; `install.json` (below) has none.
