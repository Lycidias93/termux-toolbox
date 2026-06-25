# Changelog

## Unreleased

- Initial public Termux toolbox layout.
- Add verify script and basic helper placeholders.

<!-- AUTOCLIP_V933_TOOLBOX_CHANGELOG_START -->
### 2026-06-25

- Documented AutoClip v9.3.3 polish helpers: autoclip-doctor, cgarchive, and cgrun-noclip.
- Added note for recursive guard rc=12 stale-tail behavior when literal nested cgrun appears inside a payload.
- Kept archive maintenance manual: cgarchive dry-run before apply; no automatic weekly deletion.
<!-- AUTOCLIP_V933_TOOLBOX_CHANGELOG_END -->

<!-- AUTOCLIP_V934_TOOLBOX_CHANGELOG_START -->
### 2026-06-25

- Documented AutoClip v9.3.4 stale-tail guard.
- Added behavior note for nonzero cgrun exits before latest.log updates: create cgrun_guard_*.log, repoint latest.log, and auto-cgtail the guard log.
- Recorded expected markers: version=v9.3.4-rc12-stale-tail-fix, rc12_stale_latest_guard=enabled, CGRUN_STALE_LATEST_GUARD_LOG_DONE.
<!-- AUTOCLIP_V934_TOOLBOX_CHANGELOG_END -->
