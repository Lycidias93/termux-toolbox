# Heimnetz Termux Migration Policy

`termux-toolbox` may receive only reusable, public-safe Termux tooling.

Allowed:

- Generic shell helpers
- Generic Termux setup helpers
- Generic workflow documentation
- Sanitized examples without private paths, hostnames, tokens, logs, or network inventory

Not allowed:

- Heimnetz inventory/status/device files
- Private routes, DNS/HA/VIP details, hostnames, private IPs, Tailnet/WireGuard details
- Real logs, credentials, rclone configuration, SSH material, GitHub tokens, API tokens
- Pixel/Magisk runtime state that is not reusable outside the private environment

Default sync direction remains:

```text
termux-toolbox -> heimnetz-geraete/vendor/termux-toolbox
```

There is no automatic reverse sync from Heimnetz into the public repository.
