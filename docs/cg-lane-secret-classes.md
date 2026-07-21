# cg-lane secret classes

The lane runtime and the mandatory AutoCopy wrapper use one shared secret-class contract.

Accepted values:

- `none`: full AutoCopy handoff; no secret proximity
- `public`: full AutoCopy handoff; explicitly public output
- `redacted`: full AutoCopy handoff containing already-redacted output
- `possible`: marker-only redacted AutoCopy handoff
- `sensitive`: marker-only redacted AutoCopy handoff

Unknown values fail closed.

`CGRUN_AUTO_TAIL=0` is not part of the current contract. AutoCopy remains mandatory for every class; `possible|sensitive` select the redacted marker handoff instead of suppressing the handoff.

Runtime source: `bin/cg-lane.sh`

Regression check: `verify/verify-cg-lane-secret-classes.sh`
