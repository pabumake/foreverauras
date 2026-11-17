"""Definitions of the 'Universal Cast Bar' auras (one per unit). Build with:
    python3 tools/build_import.py auras/universal-cast-bar/aura.py     -> import-player.txt, import-target.txt, import-focus.txt, import-group.txt (all three in one group)
To add another unit (pet, boss1, mouseover...) add one line to UNITS."""
from pathlib import Path

here = Path(__file__).parent
TRIGGER = (here / "trigger.lua").read_text()

WIDTH, HEIGHT = 260, 22
# unit -> (x offset, y offset) from screen center; move the aura in WeakAuras afterwards
UNITS = {
    "player": (0, -230),
    "target": (0, -275),
    "focus": (0, -320),
}


def events_for(unit: str) -> str:
    ev = [f"UNIT_SPELLCAST_{e}:{unit}" for e in (
        "START", "STOP", "FAILED", "FAILED_QUIET", "INTERRUPTED", "DELAYED",
        "CHANNEL_START", "CHANNEL_STOP", "CHANNEL_UPDATE", "INTERRUPTIBLE", "NOT_INTERRUPTIBLE")]
    if unit == "player":
        ev.append("UNIT_SPELLCAST_SENT:player")   # send time -> latency
    ev += ["PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED"] if unit in ("target", "focus") else []
    return ", ".join(ev)


def make(unit: str) -> dict:
    x, y = UNITS[unit]
    code = TRIGGER.replace('local UNIT = "player"', f'local UNIT = "{unit}"', 1)
    assert f'local UNIT = "{unit}"' in code
    return {
        "id": f"FA - Cast Bar ({unit.capitalize()})",
        "uid": f"FACastBar_{unit}_1",
        "regionType": "texture",
        "internalVersion": 91,
        "actions": {"init": {}, "start": {}, "finish": {}},
        "texture": "Interface\\Buttons\\WHITE8X8",
        "desaturate": False,
        "blendMode": "BLEND",
        "mirror": False,
        "rotate": False,
        "rotation": 0,
        "color": [0, 0, 0, 0],  # invisible anchor; the trigger draws the bar itself
        "anchorPoint": "CENTER",
        "selfPoint": "CENTER",
        "anchorFrameType": "SCREEN",
        "xOffset": x,
        "yOffset": y,
        "frameStrata": 1,
        "width": WIDTH,
        "height": HEIGHT,
        "triggers": {
            "activeTriggerMode": -10,
            "disjunctive": "all",
            1: {
                "trigger": {
                    "type": "custom",
                    "custom_type": "status",
                    "check": "event",
                    "events": events_for(unit),
                    "custom": code,
                    "debuffType": "HELPFUL",
                    "unit": "player",
                },
                "untrigger": {},
            },
        },
        "load": {
            "use_never": False,
            "use_class": False,
            "class": {"multi": {}},
            "size": {"multi": {}},
            "spec": {"multi": {}},
            "talent": {"multi": {}},
        },
        "conditions": [],
        "config": {},
        "authorOptions": [],
        "subRegions": [],
        "information": {},
        "animation": {
            "start": {"type": "none", "duration_type": "seconds"},
            "main": {"type": "none", "duration_type": "seconds"},
            "finish": {"type": "none", "duration_type": "seconds"},
        },
    }


AURAS = {unit: make(unit) for unit in UNITS}


# Parent group for a one-paste import of all units (structure copied from a group exported by ForeverAuras).
# The importer fills in controlledChildren and each child's parent itself.
GROUP = {
    "id": "FA - Cast Bars",
    "uid": "FACastBarsGroup1",
    "regionType": "group",
    "internalVersion": 91,
    "actions": {"init": {}, "start": {}, "finish": {}},
    "triggers": {
        1: {
            "trigger": {
                "type": "aura2", "unit": "player", "debuffType": "HELPFUL", "event": "Health",
                "subeventPrefix": "SPELL", "subeventSuffix": "_CAST_START", "names": {}, "spellIds": {},
            },
            "untrigger": {},
        },
    },
    "animation": {
        "start": {"type": "none", "duration_type": "seconds", "easeType": "none", "easeStrength": 3},
        "main": {"type": "none", "duration_type": "seconds", "easeType": "none", "easeStrength": 3},
        "finish": {"type": "none", "duration_type": "seconds", "easeType": "none", "easeStrength": 3},
    },
    "subRegions": [],
    "load": {"talent": {"multi": {}}, "size": {"multi": {}}, "spec": {"multi": {}}, "class": {"multi": {}}, "zoneIds": ""},
    "conditions": [],
    "config": {},
    "authorOptions": [],
    "information": {},
    "anchorPoint": "CENTER",
    "selfPoint": "CENTER",
    "anchorFrameType": "SCREEN",
    "xOffset": 0,
    "yOffset": 0,
    "frameStrata": 1,
    "alpha": 1,
    "scale": 1,
    "border": False,
    "borderEdge": "Square Full White",
    "borderBackdrop": "Blizzard Tooltip",
    "borderSize": 2,
    "borderOffset": 4,
    "borderInset": 1,
    "backdropColor": [1, 1, 1, 0.5],
}
