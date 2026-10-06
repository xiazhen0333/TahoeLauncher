# SPDX-License-Identifier: GPL-2.0-or-later
"""Live desktop check: briefly covers the desktop with stripes; requires Spectacle."""
import os
import pathlib
import shutil
import subprocess
import tempfile
import time

assert os.environ.get('WAYLAND_DISPLAY'), 'Run inside the Wayland desktop session'
os.environ['QT_QPA_PLATFORM'] = 'wayland'
from PySide6.QtCore import QObject, QPoint
from PySide6.QtGui import QGuiApplication, QImage
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtQuick import QQuickWindow
from PySide6.QtTest import QTest

root = pathlib.Path(__file__).resolve().parents[1]
plugin = pathlib.Path(os.environ['TAHOE_GLASS_PLUGIN_DIR'])
app = QGuiApplication([])
with tempfile.TemporaryDirectory(prefix='tahoe-wayland-') as directory:
    tmp = pathlib.Path(directory)
    shutil.copytree(plugin, tmp / 'native')
    shutil.copy(root / 'contents/ui/materials/glass.svg', tmp / 'glass.svg')
    (tmp / 'Harness.qml').write_text('''import QtQuick
import QtQuick.Window
import org.kde.plasma.core as PlasmaCore
import org.kde.ksvg as KSvg
import "native"
Window {
    id: backdrop
    width: 1000; height: 800; visible: true
    title: "Tahoe blur regression check"
    Rectangle { anchors.fill: parent; color: "black" }
    Repeater { model: Math.ceil(backdrop.width / 8)
        Rectangle { x: index * 8; width: 4; height: backdrop.height; color: "white" }
    }
    PlasmaCore.Dialog {
        objectName: "dialog"
        location: PlasmaCore.Types.Floating
        flags: Qt.WindowStaysOnTopHint
        backgroundHints: PlasmaCore.Types.NoBackground
        color: "transparent"
        mainItem: Item {
            objectName: "surface"
            width: 700; height: 600
            KSvg.FrameSvgItem { id: glass; anchors.fill: parent; imagePath: Qt.resolvedUrl("glass.svg").toString().replace(/^file:\\/\\//, "") }
            GlassEffects { objectName: "effects"; maskItem: glass; blurEnabled: true }
        }
    }
}
''')
    engine = QQmlApplicationEngine(str(tmp / 'Harness.qml'))
    assert engine.rootObjects(), 'Could not load the native window'
    backdrop = engine.rootObjects()[0]
    dialog = backdrop.findChild(QQuickWindow, 'dialog')
    effects = backdrop.findChild(QObject, 'effects')
    surface = backdrop.findChild(QObject, 'surface')
    def contrast():
        QTest.qWait(300)
        capture = tmp / 'screen.png'
        capture.unlink(missing_ok=True)
        path = str(capture)
        subprocess.run(['spectacle', '-b', '-n', '-o', path], check=True, timeout=10)
        # An existing Spectacle process may save after its CLI client returns.
        deadline = time.monotonic() + 5
        while not (capture.exists() and capture.read_bytes().endswith(b'IEND\xaeB`\x82')):
            assert time.monotonic() < deadline, 'Screenshot save timed out'
            QTest.qWait(50)
        screenshot = QImage(path)
        assert not screenshot.isNull(), 'No desktop screenshot'
        center = dialog.mapToGlobal(QPoint(dialog.width() // 2, dialog.height() // 2))
        ratio = dialog.screen().devicePixelRatio()
        cx, cy = round(center.x() * ratio), round(center.y() * ratio)
        values = [screenshot.pixelColor(x, y).red()
                  for y in range(cy - 10, cy + 10) for x in range(cx - 50, cx + 50)]
        mean = sum(values) / len(values)
        return (sum((v - mean) ** 2 for v in values) / len(values)) ** 0.5
    try:
        backdrop.showMaximized()
        QTest.qWait(300)
        for cycle in range(3):
            dialog.show()
            dialog.requestActivate()
            if cycle == 2:
                surface.setProperty('width', 740)
            on = contrast()
            effects.setProperty('blurEnabled', False)
            off = contrast()
            assert off > 15 and on < off * 0.15, (cycle, on, off)
            print(f'PASS: cycle {cycle + 1}, stripe contrast blur on/off {on:.2f}/{off:.2f}', flush=True)
            dialog.hide()
            effects.setProperty('blurEnabled', True)
            QTest.qWait(100)
    finally:
        dialog.close()
        backdrop.close()
        QTest.qWait(30)
