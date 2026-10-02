# SPDX-License-Identifier: GPL-2.0-or-later
"""Run with Python + PySide6. Uses real Qt Quick; KDE-only primitives are stubbed."""
import os, pathlib, shutil, tempfile, time
native_dialog = os.environ.get('TAHOE_NATIVE_DIALOG') == '1'
os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')
os.environ.setdefault('QML_DISABLE_DISK_CACHE', '1')
os.environ.setdefault('XDG_CACHE_HOME', '/tmp/tahoe-test-cache')
pathlib.Path(os.environ['XDG_CACHE_HOME']).mkdir(parents=True, exist_ok=True)
from PySide6.QtCore import QUrl, QObject, QtMsgType, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickItem, QQuickWindow
from PySide6.QtQml import QQmlEngine, QQmlComponent, QJSValue
from PySide6.QtTest import QTest, QSignalSpy
root = pathlib.Path(__file__).resolve().parents[1]
app = QGuiApplication([])
errors = []
def message(kind, context, text):
    if kind in (QtMsgType.QtWarningMsg, QtMsgType.QtCriticalMsg): errors.append(text)
qInstallMessageHandler(message)
engine = QQmlEngine()
def create(path):
    c = QQmlComponent(engine, QUrl.fromLocalFile(str(path)))
    obj = c.create()
    assert obj is not None, '\n'.join(e.toString() for e in c.errors())
    QObject.setParent(obj, engine)
    return obj
def call(obj, method, *args):
    target = engine.newQObject(obj)
    result = target.property(method).callWithInstance(target, [QJSValue(arg) for arg in args])
    assert not result.isError(), result.toString()
motion = create(root / 'contents/ui/LauncherMotion.qml')
closed = QSignalSpy(motion, motion.metaObject().method(motion.metaObject().indexOfSignal('closed()')))
call(motion, 'prepare'); call(motion, 'open'); QTest.qWait(70)
before = motion.property('surfaceScale')
assert 0.94 < before < 1, before
call(motion, 'close')
assert abs(motion.property('surfaceScale') - before) < 0.005, 'closing jumped to a fixed source'
QTest.qWait(50)
before = motion.property('surfaceScale')
call(motion, 'open')
assert abs(motion.property('surfaceScale') - before) < 0.005, 'reopening jumped to a fixed source'
QTest.qWait(300)
assert abs(motion.property('surfaceScale') - 1) < 0.0001
assert motion.property('surfaceOpacity') == 1
assert closed.count() == 0, 'an interrupted close must not hide a reopened launcher'
call(motion, 'close'); QTest.qWait(230)
assert closed.count() == 1, (closed.count(), motion.property("surfaceOpacity"), motion.property("settled"), errors)
motion.setProperty('animationsEnabled', False)
call(motion, 'open'); call(motion, 'close'); QTest.qWait(30)
assert closed.count() == 2, closed
assert motion.property('surfaceOpacity') == 0
with tempfile.TemporaryDirectory() as directory:
    tmp = pathlib.Path(directory)
    for name in ('AppsCategorized.qml', 'Scrollbar.qml', 'AppGridView.qml', 'AllAppsList.qml'):
        shutil.copy(root / 'contents/ui' / name, tmp / name)
    (tmp / 'js').mkdir()
    shutil.copy(root / 'contents/ui/js/categoryRows.js', tmp / 'js/categoryRows.js')
    kd = tmp / 'org/kde/kirigami'; kd.mkdir(parents=True)
    (kd / 'qmldir').write_text('module org.kde.kirigami\nWheelHandler 1.0 WheelHandler.qml\nsingleton Units 1.0 Units.qml\n')
    (kd / 'Units.qml').write_text('pragma Singleton\nimport QtQml\nQtObject { property int shortDuration: 100 }\n')
    (kd / 'WheelHandler.qml').write_text('import QtQuick\nItem { property var target; property bool filterMouseEvents: false; property real horizontalStepSize; property real verticalStepSize; signal wheel(var wheel) }\n')
    km = tmp / 'org/kde/kitemmodels'; km.mkdir(parents=True)
    (km / 'qmldir').write_text('module org.kde.kitemmodels\nsingleton KRoleNames 1.0 KRoleNames.qml\n')
    (km / 'KRoleNames.qml').write_text('pragma Singleton\nimport QtQml\nQtObject {}\n')
    # Delegate instrumentation measures the real GridView/ListView lifetime.
    (tmp / 'AppGridViewDelegate.qml').write_text('''import QtQuick
Item {
    property var triggerModel
    property var view
    property int itemIndex: index
    property var appData
    function resetTransientState() {}
    objectName: "instrumentedCell"
    width: 100; height: 100
    Component.onCompleted: { counter.live++; counter.peak = Math.max(counter.peak, counter.live) }
    Component.onDestruction: counter.live--
}
''')
    (tmp / 'Harness.qml').write_text('''import QtQuick
import QtQuick.Window
Window {
    width: 540; height: 400; visible: true
    property alias liveCells: counter.live
    property alias peakCells: counter.peak
    QtObject { id: counter; property int live: 0; property int peak: 0 }
    QtObject { id: root; property int columns: 5; property int cellSizeWidth: 100; property int cellSizeHeight: 100 }
    QtObject { id: fs; property real innerPadding: 15 }
    QtObject { id: main; property color contrastBgColor: "#222222"; property color textColor: "#ffffff"; property color dimmedTextColor: "#888888" }
    ListModel { id: source }
    QtObject { id: rootModel; signal refreshed(); function modelForRow(i) { return source } }
    function i18n(text) { return text }
    AppsCategorized {
        id: categories
        objectName: "categories"
        anchors.fill: parent
        model: [{ name: "Large category", modelIndex: 0 }]
    }
    Component.onCompleted: {
        for (var i = 0; i < 3000; ++i) source.append({ name: "Application " + i })
        categories.rebuildSources()
    }
}
''')
    # The configured column count must fit the real loader without an extra margin.
    drag = tmp / 'org/kde/draganddrop'; drag.mkdir(parents=True)
    (drag / 'qmldir').write_text('module org.kde.draganddrop\nStub 2.0 Stub.qml\n')
    (drag / 'Stub.qml').write_text('import QtQml\nQtObject {}\n')
    (tmp / 'AppCategorySwitcher.qml').write_text('import QtQuick\nItem { property var model; signal categorySwitched(int index) }\n')
    (tmp / 'AppListView.qml').write_text('import QtQuick\nItem { property var model; property bool showSectionSeparator }\n')
    (tmp / 'GridHarness.qml').write_text('''import QtQuick
import QtQuick.Window
Window {
    width: 500; height: 400; visible: true
    QtObject { id: counter; property int live: 0; property int peak: 0 }
    QtObject { id: root; property int columns: 5; property int cellSizeWidth: 100; property int cellSizeHeight: 100 }
    QtObject { id: fs; property real innerPadding: 15 }
    QtObject { id: main; property bool showAllApps: true; property color dimmedTextColor: "#888888" }
    QtObject { id: plasmoid; property QtObject configuration: QtObject {
        property bool showAllAppsInGrid: true; property bool showAllAppsInList: false
        property bool showAllAppsCategorized: false; property int numberColumns: 5
    } }
    ListModel { id: source }
    QtObject { id: rootModel; property int count: 0; function modelForRow(i) { return source } }
    AllAppsList { objectName: "allApps"; anchors.fill: parent }
    Component.onCompleted: { for (var i = 0; i < 20; ++i) source.append({name: "App " + i}) }
}
''')
    engine.addImportPath(str(tmp))
    obj = create(tmp / 'Harness.qml'); QTest.qWait(200)
    categories = obj.findChild(QObject, 'categories')
    rows = obj.findChild(QObject, 'categoryRowsView')
    assert rows.property('count') == 2
    assert obj.property('liveCells') < 80, obj.property('liveCells')
    call(categories, 'toggleCategory', 0); QTest.qWait(200)
    assert rows.property('count') == 601, rows.property('count')
    for y in (1500, 15000, 40000, 0):
        rows.setProperty('contentY', y); QTest.qWait(100)
        assert obj.property('liveCells') < 80, obj.property('liveCells')
    peak = obj.property('peakCells')
    call(categories, 'toggleCategory', 0); QTest.qWait(150)
    assert rows.property('count') == 2
    obj.close(); obj.deleteLater(); QTest.qWait(50)
    gridWindow = create(tmp / 'GridHarness.qml'); QTest.qWait(150)
    grid = gridWindow.findChild(QObject, 'allApps').property('viewItem')
    assert grid.property('width') == 500, 'an extra margin reduced the configured grid width'
    cells = [cell for cell in grid.property('contentItem').childItems() if cell.objectName() == 'instrumentedCell']
    assert sum(cell.y() == 0 for cell in cells) == 5, 'the configured 5 columns wrapped to 4'
    gridWindow.close(); gridWindow.deleteLater(); QTest.qWait(30)
assert not errors, '\n'.join(errors)
print(f'PASS: Qt continuous open/close, no-animation mode, 5-column grid; 3000 apps, bounded delegates (peak {peak})')

# Exercise the actual popup controller with small KDE API stubs. This verifies
# backend latching and hide/reset ordering, not native KWin rendering.
engines = [engine]
engine = QQmlEngine()
engines.append(engine)
with tempfile.TemporaryDirectory() as directory:
    tmp = pathlib.Path(directory)
    for name in ('MenuRepresentation.qml', 'LauncherMotion.qml'):
        shutil.copy(root / 'contents/ui' / name, tmp / name)
    shutil.copytree(root / 'contents/ui/materials', tmp / 'materials')
    (tmp / 'MainView.qml').write_text('import QtQuick\nItem { function reset() { counter.resets++ } function reload() { reset() } }\n')
    def module(uri, entries):
        location = tmp / uri.replace('.', '/')
        location.mkdir(parents=True)
        names = []
        for name, (content, singleton) in entries.items():
            (location / (name + '.qml')).write_text(content)
            names.append(('singleton ' if singleton else '') + name + ' 1.0 ' + name + '.qml')
        (location / 'qmldir').write_text('module ' + uri + '\n' + '\n'.join(names) + '\n')
    if not native_dialog: module('org.kde.plasma.core', {
        'Dialog': ('''import QtQuick
Item {
    width: 620; height: 520; visible: false
    default property Item mainItem
    onMainItemChanged: { if (mainItem) mainItem.parent = contentItem }
    property string title
    property color color
    property int flags
    property int location
    property int backgroundHints
    property bool hideOnWindowDeactivate
    property bool active: false
    property Item contentItem: Item { Rectangle { width: 620; height: 520 } }
    function requestActivate() { active = false; active = true }
    function update() {}
}
''', False),
        'Types': ('''pragma Singleton
import QtQml
QtObject { enum Location { Floating, TopEdge, BottomEdge } enum Hint { NoBackground, StandardBackground } }
''', True)
    })
    module('org.kde.plasma.components', {'Stub': ('pragma Singleton\nimport QtQml\nQtObject {}\n', True)})
    module('org.kde.plasma.plasmoid', {
        'Plasmoid': ('''pragma Singleton
import QtQml
QtObject {
    property int location: 2
    property rect availableScreenRect: Qt.rect(0, 0, 1920, 1080)
    property QtObject configuration: QtObject {
        property int animationBackend: 1
        property int appsIconSize: 3
        property int numberColumns: 5
        property int numberOfRows: 4
        property int launcherPosition: 2
        property int offsetX: 0
        property int offsetY: 0
        property bool floating: false
    }
}
''', True)
    })
    if not native_dialog: module('org.kde.ksvg', {'FrameSvgItem': ('import QtQuick\nItem { property string imagePath; property var margins: ({top: 8, bottom: 8, left: 8, right: 8}) }\n', False)})
    module('org.kde.kirigami', {'Units': ('pragma Singleton\nimport QtQml\nQtObject { property int longDuration: 200; property int gridUnit: 18; property var iconSizes: ({smallMedium: 22, medium: 32, large: 48, huge: 64}) }\n', True)})
    module('org.kde.plasma.plasma5support', {'DataSource': ('''import QtQml
QtObject {
    property string engine
    signal newData(string sourceName, var data)
    function connectSource(name) { Qt.callLater(function() { newData(name, {"exit code": 0, "stdout": "true\\n"}) }) }
    function disconnectSource(name) {}
}
''', False)})
    (tmp / 'PopupHarness.qml').write_text('''import QtQuick
import QtQuick.Window
import org.kde.plasma.plasmoid
Window {
    width: 1920; height: 1080; visible: true
    property alias resets: counter.resets
    QtObject { id: counter; property int resets: 0 }
    QtObject { id: kicker; signal reset(); property rect screenGeometry: Qt.rect(0,0,1920,1080) }
    QtObject { id: rootModel; function refresh() {} }
    QtObject { id: highlightItemSvg; property var margins: ({top:8,bottom:8,left:8,right:8}) }
    QtObject { id: panelSvg; property var margins: ({top:8,bottom:8,left:8,right:8}) }
    QtObject { id: dialogSvg; property var margins: ({top:8,bottom:8,left:8,right:8}) }
    function setBackend(value) { Plasmoid.configuration.animationBackend = value }
    Item { id: button; width: 48; height: 48; MenuRepresentation { launcherButton: button } }
}
''')
    engine.addImportPath(str(tmp))
    popupHarness = create(tmp / 'PopupHarness.qml'); QTest.qWait(30)
    popup = popupHarness.findChild(QObject, 'popupWindow')
    if native_dialog:
        call(popupHarness, 'setBackend', 0)
        call(popup, 'probeEffect'); QTest.qWait(30)
        call(popup, 'open'); QTest.qWait(400)
        frame = popup.property('nativeGlassFrame')
        assert frame is not None, 'native DialogBackground FrameSvg was not found'
        from PySide6.QtCore import QPoint
        mask = frame.property('mask')
        assert frame.property('imagePath').endswith('/materials/glass-panel.svg')
        assert not mask.contains(QPoint(1, 1)), 'transparent corners must not receive blur'
        assert mask.contains(QPoint(popup.width() // 2, popup.height() // 2))
        call(popup, 'closeWithLaunchAnimation'); QTest.qWait(60)
        assert popup.property('visible'), 'native window was hidden before close completed'
        call(popup, 'open'); QTest.qWait(400)
        assert popup.property('visible') and popup.property('title').endswith('|settled')
        call(popup, 'closeWithLaunchAnimation'); QTest.qWait(550)
        assert not popup.property('visible'), 'native close failed to hide the settled window'
        popupHarness.close()
        # Native KDE reports unsupported platform/shadow capabilities offscreen.
        expected = ('QObject::installEventFilter(): Cannot filter events for objects in a different thread.',
                    'Could not find any platform plugin', 'Member visible of the object PlasmaQuick::Dialog overrides',
                    "Couldn't create KWindowShadow for", 'This plugin does not support raise()')
        unexpected = [text for text in errors if not text.startswith(expected)]
        assert not unexpected, '\n'.join(unexpected)
        print('PASS: native Plasma Dialog glass mask, transparent corners, mapped reversal and deferred hide')
        raise SystemExit(0)
    call(popup, 'open'); QTest.qWait(300)
    assert popup.property('visible') and not popup.property('compositorForSession')
    call(popup, 'contextMenuOpened')
    popup.setProperty('active', False); QTest.qWait(220)
    assert popup.property('visible') and not popup.property('closing'), 'menu focus incorrectly dismissed the launcher'
    call(popup, 'contextMenuClosed'); QTest.qWait(230)
    assert not popup.property('visible') and popupHarness.property('resets') == 1
    call(popupHarness, 'setBackend', 0)
    call(popup, 'probeEffect'); QTest.qWait(30)
    assert popup.property('kwinEffectAvailable'), 'effect probe result was not decoded'
    call(popup, 'open')
    assert popup.property('compositorForSession')
    assert popup.property('title').startswith('TahoeLauncher Motion v3|')
    call(popup, 'closeWithLaunchAnimation')
    assert popup.property('visible') and popup.property('title').endswith('|close') and popupHarness.property('resets') == 1
    QTest.qWait(60); call(popup, 'toggleFromButton')
    assert popup.property('visible') and popup.property('compositorForSession')
    QTest.qWait(260)
    assert popupHarness.property('resets') == 1, 'pending close reset a reopened window'
    call(popupHarness, 'setBackend', 2)
    assert popup.property('compositorForSession'), 'backend changed in the middle of a cycle'
    call(popup, 'closeWithLaunchAnimation'); QTest.qWait(550)
    call(popup, 'open')
    assert not popup.property('compositorForSession')
    call(popup, 'closeWithLaunchAnimation'); QTest.qWait(30)
    assert not popup.property('visible')
    popupHarness.close(); popupHarness.deleteLater(); QTest.qWait(30)
assert not errors, '\n'.join(errors)
print('PASS: popup backend latching, probe, menu focus, delayed reset and compositor-close reversal')
