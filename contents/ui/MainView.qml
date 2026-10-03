/*****************************************************************************
 *   Copyright (C) 2022 by Friedrich Schriewer <friedrich.schriewer@gmx.net> *
 *                                                                           *
 *   This program is free software; you can redistribute it and/or modify    *
 *   it under the terms of the GNU General Public License as published by    *
 *   the Free Software Foundation; either version 2 of the License, or       *
 *   (at your option) any later version.                                     *
 *                                                                           *
 *   This program is distributed in the hope that it will be useful,         *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of          *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the           *
 *   GNU General Public License for more details.                            *
 *                                                                           *
 *   You should have received a copy of the GNU General Public License       *
 *   along with this program; if not, write to the                           *
 *   Free Software Foundation, Inc.,                                         *
 *   51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA .          *
 ****************************************************************************/
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components 3.0 as PlasmaComponents

import org.kde.kirigami as Kirigami

import "js/colorType.js" as ColorType

Item {
    id: main
    // Blur all foreground content together; panel opacity already supplies the fade.
    layer.enabled: root.visible && root.motionController.running && root.backendForSession !== 2 && GraphicsInfo.api !== GraphicsInfo.Software
    layer.effect: MultiEffect {
        blurEnabled: true
        blurMax: 12
        blur: root.motionController.contentBlur
        autoPaddingEnabled: false
    }
    property bool searching: (searchBar.textField.text != "")

    readonly property color textColor: Kirigami.Theme.textColor
    readonly property string textFont: Kirigami.Theme.defaultFont.family
    readonly property real textSize: 10//plasmoid.configuration.useSystemFontSettings ? Kirigami.Theme.defaultFont.pointSize : 11
    readonly property color bgColor: Kirigami.Theme.backgroundColor
    readonly property color highlightColor: Kirigami.Theme.highlightColor
    readonly property color highlightedTextColor: Kirigami.Theme.highlightedTextColor
    readonly property bool isTop: plasmoid.location == PlasmaCore.Types.TopEdge && plasmoid.configuration.launcherPosition != 2 && !plasmoid.configuration.floating

    property bool isDarkTheme: ColorType.isDark(bgColor)
    property color contrastBgColor: isDarkTheme ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(0, 0, 0, 0.065)
    property color dimmedTextColor: Qt.rgba(textColor.r, textColor.g, textColor.b, 0.7)

    property bool showAllApps: true

    function reload() {
        searchBar.textField.clear();
        appList.reset();
    }
    function reset() {
        searchBar.textField.clear();
        appList.reset();
    }

    ColumnLayout {

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        spacing: 0

        SearchBar {
            id: searchBar
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            Layout.maximumHeight: Layout.preferredHeight
            showMenuButton: !searching
            Keys.priority: Keys.AfterItem
            Keys.forwardTo: searching ? searchList : appList.viewItem
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1.5
            color: main.contrastBgColor
        }

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true
            clip: true
            AllAppsList {
                id: appList
                anchors.fill: parent
                opacity: main.searching ? 0 : 1
                visible: opacity > 0
                enabled: !main.searching
                Keys.priority: Keys.AfterItem
                Keys.forwardTo: searchBar.textField
                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                        easing.type: Easing.OutQuad
                    }
                }
            }
            SearchList {
                id: searchList
                anchors.fill: parent
                opacity: main.searching ? 1 : 0
                visible: opacity > 0
                enabled: main.searching
                Keys.priority: Keys.AfterItem
                Keys.forwardTo: searchBar.textField
                Behavior on opacity {
                    NumberAnimation {
                        duration: Kirigami.Units.shortDuration
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }
}
