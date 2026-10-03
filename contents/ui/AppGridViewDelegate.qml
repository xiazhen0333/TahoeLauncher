import QtQuick 2.12
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.kirigami as Kirigami
import QtQuick.Controls 2.15

import "../code/tools.js" as Tools

Item {
    id: gridDelegate

    property var view: GridView.view
    property int itemIndex: index
    property var appData: model
    property var triggerModel

    width: root.cellSizeWidth
    height: root.cellSizeHeight

    signal itemActivated(int index, string actionId, string argument)
    signal actionTriggered(string actionId, variant actionArgument)
    signal aboutToShowActionMenu(variant actionMenu)

    property bool isDraging: false
    property bool highlighted: false

    property bool hasActionList: ((appData.favoriteId != null && appData.favoriteId !== "") || appData.hasActionList === true)

    function openActionMenu(visualParent, x, y) {
        aboutToShowActionMenu(actionMenu);
        actionMenu.visualParent = visualParent;
        actionMenu.open(x, y);
    }

    function trigger() {
        triggerModel.trigger(itemIndex, "", null);
        root.toggle();
    }

    onAboutToShowActionMenu: actionMenu => {
        const actionList = appData.actionList || [];
        Tools.fillActionMenu(i18n, actionMenu, actionList, globalFavorites, appData.favoriteId);
    }
    onActionTriggered: (actionId, actionArgument) => {
        if (Tools.triggerAction(triggerModel, itemIndex, actionId, actionArgument) === true) {
            root.closeWithLaunchAnimation();
        }
    }

    Kirigami.Icon {
        id: appicon
        y: (2 * highlightItemSvg.margins.top)
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.iconSize
        height: width
        source: appData.decoration
    }

    PlasmaComponents.Label {
        id: appname
        text: ("name" in appData ? appData.name : appData.display)
        font.family: main.textFont
        font.pointSize: main.textSize
        font.weight: 650
        color: main.textColor
        anchors {
            top: appicon.bottom
            left: parent.left
            right: parent.right
            topMargin: Kirigami.Units.largeSpacing * 1.2
            leftMargin: Kirigami.Units.smallSpacing
            rightMargin: Kirigami.Units.smallSpacing
        }
        textFormat: Text.PlainText
        elide: Text.ElideMiddle
        horizontalAlignment: Text.AlignHCenter
        maximumLineCount: 2
        wrapMode: Text.Wrap
    }

    Rectangle {
        id: appiconHighlight

        width: appicon.width + 4 * highlightItemSvg.margins.top
        height: appicon.height + 4 * highlightItemSvg.margins.top
        radius: 14
        color: "transparent"
        border.width: 2
        border.color: main.dimmedTextColor

        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
    }

    Image {
        id: appIconShadow
        anchors.horizontalCenter: appicon.horizontalCenter
        anchors.bottom: appicon.bottom
        anchors.bottomMargin: -6
        width: appicon.width * 1.15
        height: appicon.height * 0.35
        source: "icons/app-shadow.svg"
        opacity: 0.16
        z: -1
    }
    function resetTransientState() {
        highlighted = false;
        isDraging = false;
        focus = false;
        if (actionMenu.opened && actionMenu.menu)
            actionMenu.menu.close();
    }
    GridView.onPooled: resetTransientState()
    GridView.onReused: resetTransientState()
    state: "default"
    states: [
        State {
            name: "highlight"
            when: (view.canMoveWithKeyboard ? focus : highlighted)
            PropertyChanges {
                target: appIconShadow
                opacity: 0.24
            }
            PropertyChanges {
                target: appiconHighlight
                opacity: 0.4
            }
        },
        State {
            name: "default"
            when: (view.canMoveWithKeyboard ? !focus : !highlighted)
            PropertyChanges {
                target: appIconShadow
                opacity: 0.16
            }
            PropertyChanges {
                target: appiconHighlight
                opacity: 0
            }
        }
    ]
    transitions: highlight

    MouseArea {
        id: ma
        anchors.fill: parent
        z: parent.z + 1
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: !view.movedWithWheel
        onClicked: {
            if (mouse.button == Qt.RightButton) {
                if (gridDelegate.hasActionList) {
                    var mapped = mapToItem(gridDelegate, mouse.x, mouse.y);
                    gridDelegate.openActionMenu(gridDelegate, mouse.x, mouse.y);
                }
            } else {
                trigger();
            }
        }
        onReleased: {
            isDraging: false;
        }
        onEntered: {
            // - When the movedWithKeyboard condition is broken, we do not want to
            //   select the hovered item without moving the mouse.
            // - Don't highlight separators.
            // - Don't switch category items on hover if the setting isn't enabled
            if (view.movedWithKeyboard) {
                return;
            }

            // forceActiveFocus() touches multiple items, so check for
            // activeFocus first to be more efficient.
            if (!view.activeFocus) {
                view.forceActiveFocus(Qt.MouseFocusReason);
            }
            // No need to check currentIndex first because it's
            // built into QQuickListView::setCurrentIndex() already
            view.currentIndex = itemIndex;
            highlighted = true;
        }

        onExited: {
            highlighted = false;
        }

        onPositionChanged: {
            isDraging = pressed;
            if (pressed) {
                if (appData.pluginName) {
                    dragHelper.startDrag(kicker, appData.url, appData.decoration, "text/x-plasmoidservicename", appData.pluginName);
                } else {
                    kicker.dragSource = gridDelegate;
                    dragHelper.startDrag(kicker, appData.url, appData.icon);
                }
            }
        }
    }
    ActionMenu {
        id: actionMenu
        launcherWindow: root

        onActionClicked: {
            actionTriggered(actionId, actionArgument);
        }
    }
    Transition {
        id: highlight
        PropertyAnimation {
            properties: 'opacity'
            duration: 100
            easing.type: Easing.OutQuart
        }
    }
}
