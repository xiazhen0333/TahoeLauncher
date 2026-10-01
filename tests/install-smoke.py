# SPDX-License-Identifier: GPL-2.0-or-later
import json, os, pathlib, subprocess, tempfile
root = pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as directory:
    tmp = pathlib.Path(directory)
    data = tmp / 'data with spaces'; config = tmp / 'config'; binaries = tmp / 'bin'; binaries.mkdir()
    log = tmp / 'commands.log'
    for name in ('qdbus6', 'kwriteconfig6'):
        p = binaries / name
        p.write_text('#!/bin/sh\nprintf "%s %s\\n" "' + name + '" "$*" >> "$TAHOE_TEST_LOG"\n')
        p.chmod(0o755)
    env = dict(os.environ, XDG_DATA_HOME=str(data), XDG_CONFIG_HOME=str(config), PATH=str(binaries) + os.pathsep + os.environ['PATH'], TAHOE_TEST_LOG=str(log))
    def install(*args):
        return subprocess.run(['sh', str(root / 'scripts/install.sh'), *args], env=env, capture_output=True, text=True, check=True)
    install()
    applet = data / 'plasma/plasmoids/TahoeLauncher'
    effect = data / 'kwin/effects/tahoelauncher-motion'
    assert json.loads((applet/'metadata.json').read_text())['KPlugin']['Version'] == '0.2.0'
    assert (effect/'contents/code/main.js').exists()
    (applet/'metadata.json').write_text('{"old": true}')
    install('--launcher-only')
    backups = list((data/'tahoelauncher-backups').glob('*/launcher/metadata.json'))
    assert len(backups) == 1 and json.loads(backups[0].read_text())['old'] is True
    assert log.read_text().count('kwriteconfig6') == 1, 'launcher-only installation must not change KWin preferences'
    assert 'tahoelauncher-motionEnabled true' in log.read_text()
    print('PASS: installation with spaced paths, package layout, backups and launcher-only mode')
