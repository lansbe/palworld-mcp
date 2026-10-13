#!/usr/bin/env python3
"""Embed standalone display catalogues so the MCP binary needs no resource directory."""
import base64
import json
import pathlib
import re
import subprocess

root = pathlib.Path(__file__).resolve().parents[1]
subprocess.run(['python3', str(root / 'scripts/check_localization.py')], check=True)
messages = {path.stem: json.loads(path.read_text()) for path in (root / 'locales').glob('*.json')}
encoded = base64.b64encode(json.dumps(messages, ensure_ascii=False, separators=(',', ':')).encode()).decode()
(root / 'build/EmbeddedLocalization.swift').write_text('enum EmbeddedLocalization {\n    static let encoded = "' + encoded + '"\n}\n')

version = (root / 'VERSION').read_text().strip()
if not re.fullmatch(r'(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)', version):
    raise ValueError('VERSION must contain a semantic version.')
(root / 'build/BuildInfo.swift').write_text('enum BuildInfo { static let version = "' + version + '" }\n')
