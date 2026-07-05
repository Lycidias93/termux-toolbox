# Context Pack: Repo Maintenance

Marker: `CONTEXT_REPO_MAINTENANCE_TOOLBOX_BASELINE_V1_20260705`

## Zweck

Repo-Pflege nur mit sauberem Preflight, Branch, Diff, Secret-Guard und Verify.

## Reihenfolge

1. Ist-Zustand prüfen.
2. Default-Branch bestätigen.
3. Branch erstellen.
4. Änderungen vollständig als Dateien schreiben.
5. Verify ausführen.
6. Commit lokal erzeugen.
7. Push nur explizit.

## Nicht erlaubt

- Secrets in Logs.
- DNS/HA/VIP/Route-Änderungen ohne Routeguard.
- Teilpatches als Chat-Fragmente.
