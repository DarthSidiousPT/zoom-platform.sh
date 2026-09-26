# Game fixes

Launchers for games whose own ZOOM Platform shortcut doesn't work under Proton.

While installing, `zoom-platform.sh` downloads `game-fixes/<ZOOM game GUID>.ini` from the `main` branch of this
repository, for the game being installed only. Most games have no file, and that is fine: a 404, or no network,
just means the install goes on as usual. Everything it does with the file is logged. To try a file that isn't on
`main` yet, run the script with `ZOOM_GAME_FIXES_FILE=<path to the file>`.

The GUID is the one the script prints as "ZOOM Platform UUID" (lowercase in the file name). Add a game by adding
its file, nothing in `src.sh` changes.

## Format

One `[launcher name]` section per launcher:

| Key        | Meaning                                                                                                                                                     |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `replaces` | The installer's shortcut this launcher stands in for (its name, as in the Start Menu). Several sections can replace the same one, and then the installer's own launcher isn't made at all. |
| `exe`      | What to start: a Windows path relative to the folder the replaced shortcut's target is in, with `\` between the parts.                                        |
| `workdir`  | The working directory, relative to the same folder. Optional, the folder itself when left out.                                                                |
| `args`     | Command line arguments. Optional.                                                                                                                           |

Lines starting with `#` or `;` are comments, and unknown keys are ignored so an older script can read a newer file.
If none of a shortcut's launchers can be made (say the exe isn't where the file expects it), the installer's own
launcher is kept.

## Checks

The file comes off the network and ends up in a generated shell script, so every value is checked before use.
Paths take letters, digits, space and `. _ ( ) + , -` only, must be relative, and can't contain `..`. Arguments take
letters, digits, space and `+ . _ , = : / -` only. A launcher that fails a check is skipped with a warning.
