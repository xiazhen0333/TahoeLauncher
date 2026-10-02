// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick
import QtQuick.Controls
import QtQml.Models
import org.kde.kirigami as Kirigami
import org.kde.kitemmodels as KItemModels
import "js/categoryRows.js" as CategoryRows

Item {
    id: appsCategorized
    property var model: []
    property var categorySources: []
    property var categoryRoles: []
    property int modelRevision: 0
    property var expandedCategories: ({})
    readonly property int columns: root.columns
    readonly property real availableWidth: width
    property var rowDescriptors: []
    focus: true
    Keys.forwardTo: [rowsView]

    function rebuildSources() {
        var sources = [];
        for (var i = 0; i < model.length; ++i)
            sources.push(rootModel.modelForRow(model[i].modelIndex));
        categorySources = sources;
        categoryRoles = sources.map(function (source) {
            var roles = {};
            if (!source || typeof source.get === "function")
                return roles;
            var names = ["name", "display", "decoration", "description", "favoriteId", "hasActionList", "actionList", "url", "icon", "pluginName"];
            for (var i = 0; i < names.length; ++i) {
                var role = source.KItemModels.KRoleNames.role(names[i]);
                if (role >= 0)
                    roles[names[i]] = role;
            }
            return roles;
        });
        modelRevision++;
        rebuildRows();
    }
    function rebuildRows() {
        var previousY = rowsView.contentY;
        var counts = categorySources.map(source => source ? source.count : 0);
        rowDescriptors = CategoryRows.buildRows(counts, columns, expandedCategories);
        Qt.callLater(function () {
            rowsView.contentY = Math.max(rowsView.originY, Math.min(previousY, rowsView.originY + Math.max(0, rowsView.contentHeight - rowsView.height)));
        });
    }
    function readApp(category, index) {
        var source = categorySources[category];
        if (!source || index < 0 || index >= source.count)
            return {};
        if (typeof source.get === "function")
            return source.get(index);
        var item = {
            index: index
        };
        var roles = categoryRoles[category] || {};
        var modelIndex = source.index(index, 0);
        for (var name in roles) {
            // Menus and drag metadata can be expensive. Fetch those roles
            // only when the user actually opens a menu or begins a drag.
            if (name === "actionList" || name === "url" || name === "icon" || name === "pluginName") {
                Object.defineProperty(item, name, {
                    enumerable: true,
                    get: (function (role) {
                            return function () {
                                return source.data(modelIndex, role);
                            };
                        })(roles[name])
                });
            } else {
                item[name] = source.data(modelIndex, roles[name]);
            }
        }
        return item;
    }
    function toggleCategory(category) {
        var expanded = Object.assign({}, expandedCategories);
        expanded[category] = !expanded[category];
        expandedCategories = expanded;
        rebuildRows();
    }
    function reset() {
        rowsView.currentIndex = -1;
        rowsView.positionViewAtBeginning();
    }
    onModelChanged: rebuildSources()
    onColumnsChanged: rebuildRows()
    Component.onCompleted: rebuildSources()
    Connections {
        target: rootModel
        function onRefreshed() {
            appsCategorized.rebuildSources();
        }
    }
    Instantiator {
        model: appsCategorized.categorySources
        delegate: QtObject {
            required property var modelData
            property Connections watcher: Connections {
                target: modelData
                ignoreUnknownSignals: true
                function onCountChanged() {
                    rebuildTimer.restart();
                }
                function onModelReset() {
                    rebuildTimer.restart();
                }
                function onRowsInserted() {
                    rebuildTimer.restart();
                }
                function onRowsRemoved() {
                    rebuildTimer.restart();
                }
                function onDataChanged() {
                    appsCategorized.modelRevision++;
                }
            }
        }
    }
    Timer {
        id: rebuildTimer
        interval: 0
        onTriggered: appsCategorized.rebuildRows()
    }

    ListView {
        id: rowsView
        objectName: "categoryRowsView"
        anchors.fill: parent
        clip: true
        focus: true
        boundsBehavior: Flickable.StopAtBounds
        currentIndex: -1
        reuseItems: true
        cacheBuffer: height / 2
        model: appsCategorized.rowDescriptors
        keyNavigationEnabled: false
        delegate: Loader {
            id: rowLoader
            required property var modelData
            width: appsCategorized.availableWidth
            height: modelData.kind === "header" ? 54 : root.cellSizeHeight
            sourceComponent: modelData.kind === "header" ? headerComponent : appsComponent
            ListView.onPooled: {
                if (item && typeof item.resetCells === "function")
                    item.resetCells();
            }
            ListView.onReused: {
                if (item && typeof item.resetCells === "function")
                    item.resetCells();
            }
            Component {
                id: headerComponent
                Item {
                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width
                        height: 1
                        visible: rowLoader.modelData.category > 0
                        color: main.contrastBgColor
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: fs.innerPadding / 2
                        anchors.verticalCenter: parent.verticalCenter
                        text: appsCategorized.model[rowLoader.modelData.category].name
                        color: main.textColor
                        font.bold: true
                        font.pixelSize: 15
                    }
                    Button {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        flat: true
                        visible: appsCategorized.categorySources[rowLoader.modelData.category].count > appsCategorized.columns
                        text: appsCategorized.expandedCategories[rowLoader.modelData.category] ? i18n("Show less") : i18n("Show more")
                        onClicked: appsCategorized.toggleCategory(rowLoader.modelData.category)
                    }
                }
            }
            Component {
                id: appsComponent
                Item {
                    id: appRow
                    property bool canMoveWithKeyboard: false
                    property bool movedWithKeyboard: false
                    property bool movedWithWheel: rowsView.moving
                    property int currentIndex: -1
                    function resetCells() {
                        for (var i = 0; i < cells.count; ++i) {
                            var cell = cells.itemAt(i);
                            if (cell)
                                cell.resetTransientState();
                        }
                    }
                    Row {
                        Repeater {
                            id: cells
                            model: Math.max(0, Math.min(appsCategorized.columns, appsCategorized.categorySources[rowLoader.modelData.category].count - rowLoader.modelData.firstIndex))
                            delegate: AppGridViewDelegate {
                                view: appRow
                                itemIndex: rowLoader.modelData.firstIndex + index
                                triggerModel: appsCategorized.categorySources[rowLoader.modelData.category]
                                appData: {
                                    var revision = appsCategorized.modelRevision;
                                    return appsCategorized.readApp(rowLoader.modelData.category, itemIndex);
                                }
                            }
                        }
                    }
                }
            }
        }
        ScrollBar.vertical: Scrollbar {
            active: rowsView.moving
        }
        Kirigami.WheelHandler {
            target: rowsView
            filterMouseEvents: true
        }
    }
}
