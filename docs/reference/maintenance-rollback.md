# Maintenance rollback

Before installing toolbox helpers, the workflow records the current toolbox commit and copies existing helper files from `$PREFIX/bin`.

On a toolbox update or install failure it attempts to:

1. remove helpers included by the attempted installation;
2. restore previously installed helper files;
3. reset the toolbox checkout to the pre-update commit.

The package upgrade is not automatically reversed. Termux package downgrade or repository pinning requires a separate recovery decision based on the package-manager state and available package versions.
