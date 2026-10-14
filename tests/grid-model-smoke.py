# SPDX-License-Identifier: GPL-2.0-or-later
"""Check rendered application identity after scrolling, sorting and model changes."""
import os
import pathlib
import shutil
import tempfile

os.environ.setdefault('QT_QPA_PLATFORM', 'offscreen')
os.environ.setdefault('QT_QUICK_BACKEND', 'software')
os.environ.setdefault('QML_DISABLE_DISK_CACHE', '1')

from PySide6.QtCore import QAbstractListModel, QModelIndex, QObject, QPointF, Qt, QUrl, Slot
from PySide6.QtGui import QGuiApplication
from PySide6.QtQml import QQmlComponent, QQmlEngine
from PySide6.QtQuick import QQuickItem, QQuickWindow
from PySide6.QtTest import QTest

root = pathlib.Path(__file__).resolve().parents[1]
app = QGuiApplication([])


class AppsModel(QAbstractListModel):
    def __init__(self):
        super().__init__()
        self.apps = [f'Application {i:03}' for i in range(200)]
        self.ids = list(range(1, 201))
        self.launched = None

    def index(self, row, column=0, parent=QModelIndex()):
        if parent.isValid() or not 0 <= row < len(self.apps) or column != 0:
            return QModelIndex()
        return self.createIndex(row, column, self.ids[row])

    def rowCount(self, parent=QModelIndex()):
        return 0 if parent.isValid() else len(self.apps)

    def roleNames(self):
        return {Qt.DisplayRole: b'display', Qt.UserRole + 2: b'decoration',
                Qt.UserRole + 3: b'favoriteId', Qt.UserRole + 4: b'hasActionList',
                Qt.UserRole + 5: b'actionList'}

    def data(self, index, role):
        if not index.isValid():
            return None
        name = self.apps[index.row()]
        return {Qt.DisplayRole: name, Qt.UserRole + 2: 'icon-' + name,
                Qt.UserRole + 3: name, Qt.UserRole + 4: True,
                Qt.UserRole + 5: [{'actionId': 'testAction', 'text': name}]}.get(role)

    @Slot(int, str, 'QVariant', result=bool)
    def trigger(self, row, action, argument):
        self.launched = self.apps[row]
        return True

    def reverse_layout(self):
        self.layoutAboutToBeChanged.emit()
        previous = self.persistentIndexList()
        self.apps.reverse()
        self.ids.reverse()
        self.changePersistentIndexList(previous, [self.index(len(self.apps) - 1 - i.row()) for i in previous])
        self.layoutChanged.emit()


with tempfile.TemporaryDirectory() as directory:
    tmp = pathlib.Path(directory)
    ui = tmp / 'ui'
    ui.mkdir()
    for name in ('AppGridView.qml', 'AppGridViewDelegate.qml', 'Scrollbar.qml'):
        shutil.copy(root / 'contents/ui' / name, ui / name)
    shutil.copytree(root / 'contents/ui/icons', ui / 'icons')
    shutil.copytree(root / 'contents/code', tmp / 'code')

    def module(uri, entries, version='1.0'):
        location = tmp / uri.replace('.', '/')
        location.mkdir(parents=True)
        names = []
        for name, (content, singleton) in entries.items():
            (location / (name + '.qml')).write_text(content)
            names.append(('singleton ' if singleton else '') + name + ' ' + version + ' ' + name + '.qml')
        (location / 'qmldir').write_text('module ' + uri + '\n' + '\n'.join(names) + '\n')

    module('org.kde.kirigami', {
        'Units': ('pragma Singleton\nimport QtQml\nQtObject { property int shortDuration: 1; property int largeSpacing: 4; property int smallSpacing: 2 }', True),
        'Icon': ('import QtQuick\nItem { property var source }', False),
        'WheelHandler': ('import QtQuick\nItem { property var target; property bool filterMouseEvents; property real horizontalStepSize; property real verticalStepSize; signal wheel(var wheel) }', False),
    })
    module('org.kde.plasma.components', {'Label': ('import QtQuick\nText {}', False)}, version='3.0')
    (ui / 'ActionMenu.qml').write_text('''import QtQuick
Item {
    property var launcherWindow
    property var visualParent
    objectName: "actionMenu"
    property var actionList
    property bool opened: false
    property var menu
    signal actionClicked(string actionId, var actionArgument)
    function open(x, y) {}
}
''')
    (ui / 'Harness.qml').write_text('''import QtQuick
import QtQuick.Window
Window {
    width: 500; height: 400; visible: true
    QtObject { id: root; property int cellSizeWidth: 100; property int cellSizeHeight: 100; property int iconSize: 32
        function toggle() {} function closeWithLaunchAnimation() {} }
    QtObject { id: main; property string textFont: "Sans"; property int textSize: 10; property color textColor: "white"; property color dimmedTextColor: "gray" }
    QtObject { id: plasmoid; property QtObject configuration: QtObject { property int numberColumns: 5 } }
    QtObject { id: highlightItemSvg; property var margins: ({top: 2}) }
    QtObject { id: globalFavorites }
    QtObject { id: searchBar; property QtObject textField: QtObject { property bool activeFocus: false } }
    function i18n(text) { return text }
    AppGridView { objectName: "grid"; anchors.fill: parent; model: appsModel }
}
''')
    engine = QQmlEngine()
    engine.addImportPath(str(tmp))
    model = AppsModel()
    engine.rootContext().setContextProperty('appsModel', model)
    component = QQmlComponent(engine, QUrl.fromLocalFile(str(ui / 'Harness.qml')))
    window = component.create()
    assert window is not None, '\n'.join(e.toString() for e in component.errors())
    grid = window.findChild(QObject, 'grid')

    def check_cells():
        QTest.qWait(100)
        cells = [c for c in grid.property('contentItem').childItems() if c.property('itemIndex') is not None and c.isVisible()]
        assert cells
        for cell in cells:
            index = cell.property('itemIndex')
            label = next(c for c in cell.childItems() if c.property('text') is not None)
            displayed = label.property('text')
            assert displayed == model.apps[index], (index, displayed, model.apps[index])
            icon = next(c for c in cell.childItems() if c.property('source') is not None and c.property('text') is None)
            assert icon.property('source') == 'icon-' + displayed, (index, icon.property('source'), displayed)
            assert cell.x() == (index % 5) * 100 and cell.y() == (index // 5) * 100, (index, cell.x(), cell.y())
            engine.newQObject(cell).property('trigger').call()
            assert model.launched == displayed, (index, displayed, model.launched)
        # Use actual mouse and keyboard events on a cell inside the viewport.
        cell = next(c for c in cells if 0 <= c.mapToScene(QPointF(50, 50)).y() < window.height())
        displayed = model.apps[cell.property('itemIndex')]
        point = cell.mapToScene(QPointF(50, 50)).toPoint()
        model.launched = None
        QTest.mouseClick(window, Qt.LeftButton, Qt.NoModifier, point)
        assert model.launched == displayed, (displayed, model.launched)
        grid.setProperty('currentIndex', cell.property('itemIndex'))
        grid.forceActiveFocus()
        model.launched = None
        QTest.keyClick(window, Qt.Key_Return)
        assert model.launched == displayed, (displayed, model.launched)
        QTest.mouseClick(window, Qt.RightButton, Qt.NoModifier, point)
        actions = cell.findChild(QObject, 'actionMenu').property('actionList')
        assert actions[0]['text'] == displayed, (displayed, actions)

    check_cells()
    for y in (1000, 2500, 0):
        grid.setProperty('contentY', y)
        check_cells()
    model.reverse_layout()
    check_cells()
    model.beginResetModel()
    model.apps = [f'Replacement {i:03}' for i in range(200)]
    model.endResetModel()
    check_cells()
    model.beginMoveRows(QModelIndex(), 0, 9, QModelIndex(), 100)
    moved = model.apps[:10]
    del model.apps[:10]
    model.apps[90:90] = moved
    moved_ids = model.ids[:10]
    del model.ids[:10]
    model.ids[90:90] = moved_ids
    model.endMoveRows()
    check_cells()
    model.apps = [f'Renamed {i:03}' for i in range(200)]
    model.dataChanged.emit(model.index(0), model.index(199), [])
    check_cells()
    replacement = AppsModel()
    replacement.apps = [f'Other category {i:03}' for i in range(200)]
    original = model
    engine.rootContext().setContextProperty('appsModel', replacement)
    model = replacement
    check_cells()
    model.reverse_layout()
    check_cells()
    window.close()
    window.deleteLater()
    QTest.qWait(30)
print('PASS: grid labels, icons, click, Enter and menus agree after scrolling, sorting, reset and category changes')
