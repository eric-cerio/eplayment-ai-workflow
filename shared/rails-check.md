# The rails check

The four rails (no commit or push on a protected branch, no force-push, no `versionCode` change, no
staged secret) are enforced by a hook, not by this text. If the tool you run in has not loaded that
hook, the rails are off and nothing says so. This check makes that visible.

1. Run exactly this shell command, on its own, through your shell tool. Do not combine it with
   another command, rephrase it, or explain it away:

       : android-workflow-rails-canary

   `:` does nothing, so the command is harmless if it runs.

2. Read the result:
   - **It was blocked by a hook**, with a reason starting `rails live` → the rails are live. Say
     nothing and continue.
   - **It was blocked, but the reason says the guard hook could not load its library** → the hook
     is installed but broken, and the edit rails are off. Stop and print: *"The workflow's guard
     hook is installed but broken, so the rails are off. Nothing will be committed or pushed.
     Reinstall the plugin."* Then print the row for your tool from "When the rails check fails" in
     `shared/hosts.md`. Do not continue.
   - **It ran** → the rails are off. Stop and print:
     *"The workflow's guard hook is not running in this tool, so the rails are off. Nothing will
     be committed or pushed."* Then print the row for your tool from "When the rails check fails"
     in `shared/hosts.md`. Do not continue, and do not offer to commit or push some other way.
   - **Anything else** — you were not allowed to run it, it timed out, you cannot tell what
     happened → treat it as not live and stop the same way. No answer is a no.
