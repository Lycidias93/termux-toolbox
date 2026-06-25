# Troubleshooting

## Package archive not found

Check the download directory:

```bash
cd /storage/emulated/0/Download
find . -maxdepth 2 -iname '*termux*toolbox*' -print
```

## `unzip: command not found`

```bash
pkg install unzip
```

## Script is not executable

```bash
chmod +x path/to/script.sh
```

## Syntax check fails

Run:

```bash
bash -n path/to/script.sh
```

Common causes:

- file was edited with broken quoting
- incomplete copy/paste
- Windows line endings
- missing closing quote or bracket

## Windows line endings

Detect:

```bash
grep -RIl $'\r' .
```

Fix a single file:

```bash
sed -i 's/\r$//' path/to/file
```

## Shared storage path fails

Run once and approve Android permission:

```bash
termux-setup-storage
```

Then retry:

```bash
ls /storage/emulated/0/Download
```

## Temporary directory permission issue

Use Termux temp instead of system temp:

```bash
export TMPDIR="${PREFIX:-/data/data/com.termux/files/usr}/tmp"
mkdir -p "$TMPDIR"
```

## Termux:API command missing

```bash
pkg install termux-api
```

Also install and enable the Android Termux:API companion app.

## Git push fails

Check authentication and remote:

```bash
gh auth status
git remote -v
git status --short
```

Do not paste credentials into logs or command output.

## cgrun/cgtail not found

Run toolbox install again:

```bash
cd "$HOME/src/termux-toolbox"
bash ./install.sh
```

Then open a new shell or reload your shell profile.
