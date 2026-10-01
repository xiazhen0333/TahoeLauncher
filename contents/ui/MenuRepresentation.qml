/*****************************************************************************
 *   Copyright (C) 2014 by Weng Xuetian <wengxt@gmail.com>                   *
 *   Copyright (C) 2013-2017 by Eike Hein <hein@kde.org>                     *
 *   Copyright (C) 2021 by Prateek SU <pankajsunal123@gmail.com>             *
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
import QtQuick.Layouts
import QtQml
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasmoid
import org.kde.ksvg as KSvg
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasma5support as P5Support

PlasmaCore.Dialog {
    id: root

    objectName: "popupWindow"
    flags: Qt.WindowStaysOnTopHint

    // Floating disables KWin's generic edge-slide protocol for this window.
    // popupPosition() still handles placement next to the user's panel.
    location: PlasmaCore.Types.Floating
    color: "transparent"
    hideOnWindowDeactivate: false
    property bool closing: false
    property bool activatedOnce: false
    property int openContextMenus: 0
    property bool kwinEffectAvailable: false
    property bool compositorForSession: false
    property int backendForSession: 1
    property real anchorX: 0.5
    property real anchorY: 0.5
    property int travel: 0
    readonly property real durationFactor: Math.max(0, Kirigami.Units.longDuration / 200)
    readonly property bool blurEnabled: compositorForSession || (visible && !closing && motion.settled && motion.surfaceOpacity >= 0.999)
    backgroundHints: blurEnabled ? PlasmaCore.Types.StandardBackground : PlasmaCore.Types.NoBackground
    title: compositorForSession ? "TahoeLauncher Motion v2|" + anchorX.toFixed(4) + "," + anchorY.toFixed(4) + "," + travel : "TahoeLauncher"
    onBackgroundHintsChanged: Qt.callLater(updateNativeBackground)

    property int iconSize: {
        switch (Plasmoid.configuration.appsIconSize) {
        case 0:
            return Kirigami.Units.iconSizes.smallMedium;
        case 1:
            return Kirigami.Units.iconSizes.medium;
        case 2:
            return Kirigami.Units.iconSizes.large;
        case 3:
            return Kirigami.Units.iconSizes.huge;
        default:
            return 64;
        }
    }

    property int columns: Plasmoid.configuration.numberColumns

    property int cellSizeHeight: iconSize + Kirigami.Units.gridUnit * 2 + (2 * Math.max(highlightItemSvg.margins.top + highlightItemSvg.margins.bottom, highlightItemSvg.margins.left + highlightItemSvg.margins.right))
    property int cellSizeWidth: cellSizeHeight //+ Kirigami.Units.gridUnit
    property int rows: Plasmoid.configuration.numberOfRows

    onVisibleChanged: {
        if (visible) {
            hiddenReset.stop();
            activatedOnce = false;
            closing = false;
            updatePosition();
            if (!compositorForSession) {
                motion.prepare();
                motion.open();
            }
            Qt.callLater(updateNativeBackground);
            requestActivate();
        } else {
            // A compositor close retains the last frame. Do not reset the
            // search/model until that frame has finished fading away.
            if (compositorForSession) {
                closing = true;
                hiddenReset.restart();
            } else {
                closing = false;
                reset();
            }
        }
    }
    onActiveChanged: {
        if (active)
            activatedOnce = true;
        else
            Qt.callLater(maybeDismiss);
    }
    onWidthChanged: updatePosition()
    onHeightChanged: updatePosition()

    function updatePosition() {
        if (!parent)
            return;
        var pos = popupPosition(width, height);
        x = pos.x;
        y = pos.y;
        if (Plasmoid.configuration.launcherPosition === 2) {
            anchorX = 0.5;
            anchorY = 0.5;
            travel = 0;
        } else {
            var buttonCenter = parent.mapToGlobal(parent.width / 2, parent.height / 2);
            anchorX = Math.max(0, Math.min(1, (buttonCenter.x - x) / Math.max(1, width)));
            anchorY = Plasmoid.location === PlasmaCore.Types.TopEdge ? 0 : 1;
            travel = anchorY === 0 ? -8 : 8;
        }
    }
    function open() {
        hiddenReset.stop();
        if (visible) {
            closing = false;
            motion.open();
            requestActivate();
            return;
        }
        // Latch the backend for this entire show/hide cycle, including reversal.
        if (!closing) {
            backendForSession = Plasmoid.configuration.animationBackend;
            compositorForSession = backendForSession === 0 && kwinEffectAvailable;
        }
        closing = false;
        updatePosition();
        visible = true;
        probeEffect();
    }
    function toggle() {
        closeWithLaunchAnimation();
    }
    function toggleFromButton() {
        if (!visible || closing)
            open();
        else
            closeWithLaunchAnimation();
    }
    function closeWithLaunchAnimation() {
        if (!visible || closing)
            return;
        closing = true;
        if (compositorForSession)
            visible = false;
        else
            motion.close();
    }
    function maybeDismiss() {
        if (!active && visible && activatedOnce && !closing && openContextMenus === 0)
            closeWithLaunchAnimation();
    }
    function contextMenuOpened() {
        openContextMenus++;
    }
    function contextMenuClosed() {
        openContextMenus = Math.max(0, openContextMenus - 1);
        Qt.callLater(maybeDismiss);
    }
    function updateNativeBackground() {
        var kids = contentItem ? contentItem.children : [];
        for (var i = 0; i < kids.length; ++i) {
            if (kids[i] && kids[i] !== fs)
                kids[i].visible = compositorForSession;
        }
    }
    function reset() {
        main.reset();
    }
    function probeEffect() {
        if (Plasmoid.configuration.animationBackend === 0 && !effectProbe.pending) {
            effectProbe.pending = true;
            effectProbe.connectSource(effectProbe.command);
        }
    }
    property QtObject effectProbeObject: P5Support.DataSource {
        id: effectProbe
        engine: "executable"
        property bool pending: false
        readonly property string command: "timeout 2 sh -c 'for client in qdbus6 qdbus-qt6 qdbus; do if command -v \"$client\" >/dev/null 2>&1; then \"$client\" org.kde.KWin /Effects org.kde.kwin.Effects.isEffectLoaded tahoelauncher-motion; exit; fi; done; printf false'"
        onNewData: (sourceName, data) => {
            root.kwinEffectAvailable = data["exit code"] === 0 && /^(true|1)$/.test(String(data["stdout"]).trim());
            disconnectSource(sourceName);
            pending = false;
        }
    }
    property QtObject hiddenResetTimer: Timer {
        id: hiddenReset
        interval: Math.ceil(200 * root.durationFactor) + 50
        onTriggered: {
            if (!root.visible) {
                root.closing = false;
                root.reset();
            }
        }
    }
    property Item motionController: LauncherMotion {
        id: motion
        animationsEnabled: root.backendForSession !== 2
        durationFactor: root.durationFactor
        travel: root.travel
        onClosed: {
            if (root.closing && !root.compositorForSession)
                root.visible = false;
        }
    }

    function popupPosition(width, height) {
        var screenAvail = Plasmoid.availableScreenRect;
        var screen = /*Geom*/ kicker.screenGeometry;
        //QtBug - QTBUG-64115
        /*var screen = Qt.rect(screenAvail.x + screenGeom.x,
				screenAvail.y + screenGeom.y,
				screenAvail.width,
				screenAvail.height);*/

        var offset = 0;
        if (Plasmoid.configuration.offsetX > 0 && Plasmoid.configuration.floating) {
            offset = Plasmoid.configuration.offsetX;
        } else {
            offset = Plasmoid.configuration.floating ? parent.height * 0.35 : 0;
        }
        // Fall back to bottom-left of screen area when the applet is on the desktop or floating.
        var x = offset;
        var y = screen.height - height - offset;
        var horizMidPoint = screen.x + (screen.width / 2);
        var vertMidPoint = screen.y + (screen.height / 2);
        var appletTopLeft = parent.mapToGlobal(0, 0);
        var appletBottomLeft = parent.mapToGlobal(0, parent.height);
        if (Plasmoid.configuration.launcherPosition != 0) {
            x = horizMidPoint - width / 2;
        } else {
            x = (appletTopLeft.x < horizMidPoint) ? screen.x : (screen.x + screen.width) - width;
            if (Plasmoid.configuration.floating) {
                if (appletTopLeft.x < horizMidPoint) {
                    x += offset;
                } else if (appletTopLeft.x + width > horizMidPoint) {
                    x -= offset;
                }
            }
        }
        if (Plasmoid.configuration.launcherPosition != 2) {
            if (Plasmoid.location == PlasmaCore.Types.TopEdge) {
                if (Plasmoid.configuration.floating) {
                    /*this is floatingAvatar.width*/
                    if (Plasmoid.configuration.offsetY > 0) {
                        offset = (125 * 1) / 2 + Plasmoid.configuration.offsetY;
                    } else {
                        offset = (125 * 1) / 2 + parent.height * 0.125;
                    }
                }
                y = screen.y + parent.height + panelSvg.margins.bottom + offset;
            } else {
                if (Plasmoid.configuration.offsetY > 0) {
                    offset = Plasmoid.configuration.offsetY;
                }
                y = screen.y + screen.height - parent.height - height - panelSvg.margins.top - offset * 2.5;
            }
        } else {
            y = vertMidPoint - height / 2;
        }
        return Qt.point(x, y);
    }

    mainItem: FocusScope {
        id: fs
        focus: true
        width: (root.cellSizeWidth * Plasmoid.configuration.numberColumns) + innerPadding * 2 + dialogSvg.margins.left + dialogSvg.margins.right
        // Searchbar.height + separator.height  + categories switcher.height
        height: 40 + 2 + 40 + (root.cellSizeHeight * rows) + innerPadding + dialogSvg.margins.top + dialogSvg.margins.bottom

        // We want the MainView to have an uniform margin through different plasma themes
        property real innerPadding: 15

        // Whole panel (theme background, content). Animated as one unit.
        Item {
            id: panel
            width: parent.width
            height: parent.height
            enabled: !root.closing
            opacity: root.compositorForSession ? 1 : motion.surfaceOpacity
            y: root.compositorForSession ? 0 : motion.offsetY
            transform: Scale {
                origin.x: panel.width * root.anchorX
                origin.y: panel.height * root.anchorY
                xScale: root.compositorForSession ? 1 : motion.surfaceScale
                yScale: xScale
            }

            // Theme background. KWin blurs whatever is behind the window, so this
            // only has to provide the glass surface itself.
            KSvg.FrameSvgItem {
                id: dialogBackground
                visible: !root.compositorForSession
                anchors.fill: parent
                imagePath: "dialogs/background"
            }

            MainView {
                id: main
                width: parent.width - (fs.innerPadding)
                height: parent.height - (fs.innerPadding * 2)
                x: fs.innerPadding
                y: fs.innerPadding
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                root.closeWithLaunchAnimation();
                event.accepted = true;
            }
        }
    }

    function refreshModel() {
        main.reload();
    }

    Component.onCompleted: {
        kicker.reset.connect(reset);
        rootModel.refresh();
        probeEffect();
        Qt.callLater(updateNativeBackground);
    }
}
