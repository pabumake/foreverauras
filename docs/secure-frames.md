# Secure (click-to-cast) frames vs dynamic icons

**Decision for the warlock aura: display-only, no secure buttons.** A queue that scrolls cannot also be clickable in combat. If a future aura needs clicking, read this first.

## The rule
A `SecureActionButtonTemplate` button (type=spell, spell=<name>) casts on click, but its spell/attributes cannot change in combat, and the frame itself (and every frame it is parented/anchored through) cannot be created, shown, hidden, moved, resized or re-targeted in combat. Only alpha changes are allowed.

## What was tried and what failed (in order)
1. Secure buttons in a row, anchored to the aura region -> WeakAuras warning **"Secure frame detected. Find more information: .../wiki/Protected-Frames"**. Anchoring a secure frame through a chain to the region locks the region; WeakAuras then trips when it shows/hides/moves it. Fix: anchor to `UIParent`, never to the WA region.
2. Plain wrapper frame around each button, `wrapper:SetShown()` in combat -> **`ADDON_ACTION_BLOCKED ... 'Frame:SetShown()'`**. A parent of a protected frame is protected too. So "stack all spells per slot, show one" does not work.
3. Alpha-only fixed layout works for clicking but cannot scroll or compact (gaps, invisible slots still clickable).
4. Writing a global (`_G[NAME] = box`) -> WeakAuras warning "The aura has overwritten the global ...". Unrelated to secure frames but hit at the same time (see weakauras-workflow.md).

## Options if clicking is required
- Fixed one-button-per-spell row, alpha only, optionally numbered badges for "next 3". No scrolling.
- Display-only scrolling queue plus a separate fixed clickable row (two rows, more screen space).
- True in-combat dynamic clicking would need SecureHandler restricted-environment snippets driven by state drivers/macro conditionals; those cannot see aura state, so it was not pursued.
- Anything secure: build all frames out of combat (`InCombatLockdown()` guard), anchor to `UIParent`, change only alpha in combat.
