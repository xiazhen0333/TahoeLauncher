// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

// Retargetable fallback. Behaviors retain the current value on interruption.
Item {
    id: motion
    property bool requestedOpen: false
    property bool closeRequested: false
    property bool animationsEnabled: true
    property real durationFactor: 1
    property real openingScale: 0.94
    property real closingScale: 0.96
    property real surfaceScale: openingScale
    property real surfaceOpacity: 0
    property real travel: 8
    readonly property real offsetY: travel * (1 - Math.min(1, Math.max(0, (surfaceScale - openingScale) / (1 - openingScale))))
    readonly property bool settled: !scaleAnimation.running && !opacityAnimation.running
    signal closed
    onSurfaceOpacityChanged: {
        if (surfaceOpacity <= 0.001)
            Qt.callLater(finishClose);
    }
    function finishClose() {
        if (closeRequested && !requestedOpen && surfaceOpacity <= 0.001) {
            closeRequested = false;
            closed();
        }
    }

    function prepare() {
        scaleAnimation.stop();
        opacityAnimation.stop();
        requestedOpen = false;
        closeRequested = false;
        scaleBehavior.enabled = false;
        opacityBehavior.enabled = false;
        surfaceScale = openingScale;
        surfaceOpacity = 0;
        scaleBehavior.enabled = Qt.binding(() => motion.animationsEnabled && motion.durationFactor > 0);
        opacityBehavior.enabled = Qt.binding(() => motion.animationsEnabled && motion.durationFactor > 0);
    }
    function open() {
        requestedOpen = true;
        closeRequested = false;
        surfaceScale = 1;
        surfaceOpacity = 1;
    }
    function close() {
        requestedOpen = false;
        closeRequested = true;
        surfaceScale = closingScale;
        surfaceOpacity = 0;
        Qt.callLater(finishClose);
    }
    Behavior on surfaceScale {
        id: scaleBehavior
        enabled: motion.animationsEnabled && motion.durationFactor > 0
        NumberAnimation {
            id: scaleAnimation
            duration: Math.round((motion.requestedOpen ? 260 : 180) * motion.durationFactor)
            easing.type: motion.requestedOpen ? Easing.OutCubic : Easing.InCubic
        }
    }
    Behavior on surfaceOpacity {
        id: opacityBehavior
        enabled: motion.animationsEnabled && motion.durationFactor > 0
        NumberAnimation {
            id: opacityAnimation
            duration: Math.round((motion.requestedOpen ? 130 : 180) * motion.durationFactor)
            easing.type: motion.requestedOpen ? Easing.OutQuad : Easing.InQuad
        }
    }
}
