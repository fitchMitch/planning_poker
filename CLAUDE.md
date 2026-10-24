<!-- rtk-instructions v2 -->
# Command output

Command output here is condensed to save tokens, keeping every signal and
dropping costly noise. Treat it as the complete result: run commands
normally, and batch related commands into one call to avoid extra turns.
Truncated results state their recovery path in their own output. Re-run a
command as `rtk bypass <cmd>` only when its result is unusable: empty when
output was clearly expected, contradicting its exit code, or garbled.
<!-- /rtk-instructions -->

Après chaque apport d'une nouvelle fonctionnalité, ajouter les tests cucumber correspondant aux ajouts et faire en sorte que les tests passent. Poser des questions fonctionnelles si nécessaire.
