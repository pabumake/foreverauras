"""Definition of the 'Ranged Range Indicator' aura. Build with: python3 tools/build_import.py auras/ranged-range-indicator/aura.py"""
from pathlib import Path

here = Path(__file__).parent
trigger_code = (here / "trigger.lua").read_text()

ID = "FA - Ranged Range Indicator"

AURA = {
    "id": ID,
    "uid": "FARangedRange1",
    "regionType": "texture",
    "internalVersion": 70,
    "parent": None,
    "texture": "Interface\\Buttons\\WHITE8X8",
    "desaturate": False,
    "blendMode": "BLEND",
    "mirror": False,
    "rotate": False,
    "rotation": 0,
    "color": [0.8, 0, 0, 0.85],
    "customText": "function() return aura_env.text or '' end",
    "customTextUpdate": "update",
    "anchorPoint": "CENTER",
    "selfPoint": "CENTER",
    "anchorFrameType": "SCREEN",
    "xOffset": 0,
    "yOffset": -120,
    "frameStrata": 1,
    "width": 140,
    "height": 50,
    "shadowColor": [0, 0, 0, 1],
    "shadowXOffset": 1,
    "shadowYOffset": -1,
    "triggers": {
        "activeTriggerMode": -10,
        "disjunctive": "all",
        1: {
            "trigger": {
                "type": "custom",
                "custom_type": "status",
                "check": "event",
                "events": "PLAYER_TARGET_CHANGED, FRAME_UPDATE",
                "custom": trigger_code,
                "debuffType": "HELPFUL",
                "unit": "player",
            },
            "untrigger": {},
        },
    },
    "load": {
        "use_never": False,
        "use_class": False,
        "class": {"multi": {
            "HUNTER": True, "MAGE": True, "WARLOCK": True, "PRIEST": True,
            "EVOKER": True, "SHAMAN": True, "DRUID": True,
        }},
        "size": {"multi": {}},
        "spec": {"multi": {}},
        "talent": {"multi": {}},
    },
    "conditions": [],
    "config": {},
    "authorOptions": [],
    "subRegions": [
        {"type": "subbackground"},
    ],
    "information": {},
    "animation": {
        "start": {"type": "none", "duration_type": "seconds"},
        "main": {"type": "none", "duration_type": "seconds"},
        "finish": {"type": "none", "duration_type": "seconds"},
    },
}
AURA = {k: v for k, v in AURA.items() if v is not None}
