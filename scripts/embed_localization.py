#!/usr/bin/env python3
"""Embed standalone display catalogues so the MCP binary needs no resource directory."""
import base64
import json
import pathlib
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
subprocess.run(['python3', str(root / 'scripts/check_localization.py')], check=True)
messages = {path.stem: json.loads(path.read_text()) for path in (root / 'locales').glob('*.json')}
encoded = base64.b64encode(json.dumps(messages, ensure_ascii=False, separators=(',', ':')).encode()).decode()
(root / 'build/EmbeddedLocalization.swift').write_text('enum EmbeddedLocalization {\n    static let encoded = "' + encoded + '"\n}\n')
