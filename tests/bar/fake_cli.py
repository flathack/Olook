#!/usr/bin/env python3
"""No-network mail engine fixture used only by the bar interaction test."""
import json
import sys
from pathlib import Path
args = sys.argv[1:]
if args == ["--argv-stdin"]:
    args = json.loads(sys.stdin.readline())
account = {"id": "qa", "name": "QA", "email": "qa@example.test", "demo": True, "authorized": True, "unread": 1}
message = {"account": "qa", "folder": "INBOX", "uid": 1, "subject": "Bar fixture", "fromAddr": "qa@example.test", "seen": False, "date": 1}
deleted = Path(__file__).with_name("deleted")
result = {"ok": True}
if "status" in args:
    result.update(accounts=[account], configured=True, unread=0 if deleted.exists() else 1, messages=[] if deleted.exists() else [message])
elif "folders" in args:
    result["folders"] = [{"name": "INBOX", "special": "inbox"}, {"name": "Archive", "special": "archive"}]
elif "list" in args:
    result["messages"] = [] if deleted.exists() else [message]
elif "delete" in args:
    deleted.touch()
    result.update(deleted=[1], to="Trash")
print(json.dumps(result))
