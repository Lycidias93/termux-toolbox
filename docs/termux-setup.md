# Termux setup baseline

This page describes a clean Termux setup for the toolbox workflow. It is intentionally generic and does not include private host names, account details, SSH material, or home-network configuration.

## Base setup

```bash
pkg update
pkg upgrade
pkg install git gh openssh termux-api coreutils findutils grep gawk sed tar unzip zip jq
```

Optional utilities that are useful for maintenance workflows:

```bash
pkg install rsync diffutils patch procps tree nano vim
```

## Storage access

Run this once when scripts need shared storage:

```bash
termux-setup-storage
```

After approval, shared storage is usually available below:

```text
/storage/emulated/0
```

Keep repository work inside Termux home when possible:

```text
$HOME/src
```

Use shared storage mainly for downloads, package handoff, and files that need to be opened by Android apps.

## Recommended directory layout

```text
$HOME/src/termux-toolbox
$HOME/.chatgpt-output
/storage/emulated/0/Download
```

## Safety defaults

- keep logs out of Git
- keep credentials out of Git
- keep device-specific restore material private
- use example files for public configuration
- verify scripts before running them
- prefer complete files and packages over partial edits

## Verify

```bash
cd "$HOME/src/termux-toolbox"
bash ./verify/verify-termux-toolbox.sh
```
