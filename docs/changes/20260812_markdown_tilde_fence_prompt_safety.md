# Markdown tilde-fence prompt safety

Live Android/ChatGPT evidence after the V2 delayed TTY-tail drain still showed a successful `cg-handoff` followed by Bash PS2 (`>`).

The V2 fixture proved kernel/TTY tail draining, but the live failure can occur earlier: the parent interactive Bash/Readline layer may already have consumed Markdown closing backticks into its own parser buffer before the child runs. A child process cannot drain bytes that are no longer in the terminal driver.

Executable shell handoffs therefore use Markdown tilde fences (`~~~bash` / `~~~`) instead of backtick fences. A leaked tilde fence is a complete shell token and cannot open Bash command substitution. The native shell guard additionally installs no-op aliases for the supported tilde fence tokens so leaked fence lines are silent after runtime installation.

TTY-tail drain V2 and `stdin_mode=dev-null` remain required defense-in-depth for their separate failure classes.
