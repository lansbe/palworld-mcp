#!/usr/bin/env python3
"""Package the signed standalone MCP bridge with its license and installer."""
import hashlib
import pathlib
import shutil
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
subprocess.run(['sh', str(ROOT / 'scripts/build.sh')], check=True)
version = (ROOT / 'VERSION').read_text().strip()
destination = ROOT / 'dist' / f'palworld-mcp-{version}-macos-arm64.zip'
destination.parent.mkdir(exist_ok=True)
with tempfile.TemporaryDirectory(prefix='mcp-package-', dir=ROOT / 'build') as temporary:
    folder = pathlib.Path(temporary) / 'Palworld MCP'
    folder.mkdir()
    for name in ['LICENSE', 'README.md', 'CONTRIBUTING.md', 'SECURITY.md']:
        shutil.copy2(ROOT / name, folder)
    shutil.copy2(ROOT / 'build/palworld-mcp', folder)
    shutil.copy2(ROOT / 'scripts/Install.command', folder)
    subprocess.run(['codesign', '--verify', '--strict', str(folder / 'palworld-mcp')], check=True)
    if destination.exists():
        destination.unlink()
    subprocess.run(['ditto', '-c', '-k', '--norsrc', '--keepParent', str(folder), str(destination)], check=True)
digest = hashlib.sha256(destination.read_bytes()).hexdigest()
destination.with_suffix('.zip.sha256').write_text(f'{digest}  {destination.name}\n')
print(f'Built dist/{destination.name}')
