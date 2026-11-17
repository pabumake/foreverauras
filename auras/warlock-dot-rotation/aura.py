"""Definition of the 'Warlock DoT Rotation' aura. Build with: python3 tools/build_import.py auras/warlock-dot-rotation/aura.py"""
from pathlib import Path

here = Path(__file__).parent
trigger_code = (here / "trigger.lua").read_text()

ID = "FA - Warlock DoT Rotation"

AURA = {
    "id": ID,
    "uid": "FAWarlockDots1",
    "regionType": "texture",
    "internalVersion": 91,  # current ForeverAuras 1.4.3; older values run Modernize steps that need fields (e.g. actions)
    "actions": {"init": {}, "start": {}, "finish": {}},
    "texture": "Interface\\Buttons\\WHITE8X8",
    "desaturate": False,
    "blendMode": "BLEND",
    "mirror": False,
    "rotate": False,
    "rotation": 0,
    "color": [0, 0, 0, 0],  # invisible anchor; the trigger draws the clickable icon row itself
    "anchorPoint": "CENTER",
    "selfPoint": "CENTER",
    "anchorFrameType": "SCREEN",
    "xOffset": 0,
    "yOffset": -200,
    "frameStrata": 1,
    "width": 142,   # = queue width (48+38+38 + 2 gaps); the aura is the drag handle for the queue
    "height": 48,
    "triggers": {
        "activeTriggerMode": -10,
        "disjunctive": "all",
        1: {
            "trigger": {
                "type": "custom",
                "custom_type": "status",
                "check": "event",
                "events": "PLAYER_TARGET_CHANGED, SPELLS_CHANGED, FRAME_UPDATE, UNIT_SPELLCAST_SUCCEEDED:player",
                "custom": trigger_code,
                "debuffType": "HELPFUL",
                "unit": "player",
            },
            "untrigger": {},
        },
    },
    "load": {
        "use_never": False,
        "use_class": True,
        "class": {"single": "WARLOCK", "multi": {"WARLOCK": True}},
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
