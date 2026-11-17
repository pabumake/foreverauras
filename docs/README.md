# Docs

Knowledge base for building WeakAuras for **WoW Forever** (ForeverAuras addon). Read in this order when starting a new aura:

| Doc | Read it for |
|-----|-------------|
| [weakauras-workflow.md](weakauras-workflow.md) | How an aura is defined, built into an import string, imported, and updated. Required fields, trigger conventions, sandbox rules. |
| [wow-forever.md](wow-forever.md) | What is different about Forever (Classic+ on the modern client): ranks, spell names/IDs, hidden ("secret") aura data in combat, where the game files are, which web sources work. |
| [secure-frames.md](secure-frames.md) | Why clickable (click-to-cast) icons and dynamic icons conflict, the errors you get, and the decision taken. |
| [testing.md](testing.md) | Testing without the game (mock harness), debugging in game, checklist before handing an aura over. |
| [warlock-dot-rotation.md](warlock-dot-rotation.md) | Design record of the warlock aura: rotation, DoT tracking, history of what failed and why. The worked example for other rotation/uptime auras. |

Per-aura user docs live next to the aura in `auras/<name>/README.md`.
