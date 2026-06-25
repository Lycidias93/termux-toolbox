# Restore on a new Termux device

This is a public-safe restore outline for the toolbox. It is not a full private environment restore.

## Goal

Recreate the reusable toolbox workflow without copying private device state.

## Steps

```bash
pkg update
pkg upgrade
pkg install git gh openssh termux-api coreutils findutils grep gawk sed tar unzip zip jq
termux-setup-storage
mkdir -p "$HOME/src"
cd "$HOME/src"
git clone https://github.com/Lycidias93/termux-toolbox.git
cd termux-toolbox
bash ./install.sh
bash ./verify/verify-termux-toolbox.sh
```

## Optional setup

```bash
mkdir -p "$HOME/.chatgpt-output"
```

Copy or adapt example files only:

```text
termux/termux.properties.example
templates/*.example, when present
```

## Do not blindly restore

Do not copy old device state directly into a new public setup. Review and migrate private files manually.

Keep these private:

```text
SSH material
GitHub authentication state
cloud backup config
raw shell history
private restore notes
local host aliases
private network details
raw logs
```

## Verification checklist

```bash
command -v cgprep
command -v cclear
command -v cgrun
command -v cgtail
command -v cgclean
cd "$HOME/src/termux-toolbox"
bash ./verify/verify-termux-toolbox.sh
```

Run a smoke command:

```bash
cgrun 'set -euo pipefail; echo "toolbox smoke"; echo "RESULT: TOOLBOX_SMOKE_DONE"'
cgtail 40
```
