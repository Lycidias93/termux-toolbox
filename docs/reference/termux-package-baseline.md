# Termux package baseline

This is a public-safe package reference for the toolbox workflow. It is not a full device backup.

## Core

```text
git
gh
openssh
coreutils
findutils
grep
gawk
sed
tar
unzip
zip
jq
termux-api
```

## Useful maintenance packages

```text
rsync
diffutils
patch
procps
tree
nano
vim
```

## Why this is not a full dump

Raw package lists from a real device can reveal personal workflows, device state, timing, or private integration choices. The public baseline stays intentionally generic.

## Minimal install command

```bash
pkg install git gh openssh termux-api coreutils findutils grep gawk sed tar unzip zip jq
```
