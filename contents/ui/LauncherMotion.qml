// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

// A critically damped spring preserves position and velocity on retargeting.
Item {
    id: motion
    property bool requestedOpen: false
    property bool closeRequested: false
    property bool animationsEnabled: true
    property real durationFactor: 1
    property real openingScale: 0.91
    property real closingScale: 0.91
    property real surfaceScale: openingScale
    property real surfaceOpacity: 0
    property real contentOpacity: 0
    property real scaleVelocity: 0
    property real opacityVelocity: 0
    property real contentVelocity: 0
    property real revealDelay: 0
    property real travel: 8
    property bool running: false
    property real elapsedFrames: 0
    property string compositorFrame: "close|0.91000,0.00000"
    readonly property real offsetY: travel * (1 - Math.min(1, Math.max(0, (surfaceScale - openingScale) / (1 - openingScale))))
    readonly property bool settled: !running
    signal closed

    function prepare() {
        running = false;
        requestedOpen = false;
        closeRequested = false;
        surfaceScale = openingScale;
        surfaceOpacity = 0;
        contentOpacity = 0;
        scaleVelocity = opacityVelocity = contentVelocity = 0;
        revealDelay = 0.06 * durationFactor;
        elapsedFrames = 0;
        publishFrame();
    }
    function open() {
        requestedOpen = true;
        closeRequested = false;
        start();
        publishFrame();
    }
    function close() {
        requestedOpen = false;
        closeRequested = true;
        revealDelay = 0;
        start();
        publishFrame();
    }
    function start() {
        if (!animationsEnabled || durationFactor <= 0) {
            surfaceScale = requestedOpen ? 1 : closingScale;
            surfaceOpacity = contentOpacity = requestedOpen ? 1 : 0;
            scaleVelocity = opacityVelocity = contentVelocity = 0;
            finish();
        } else {
            if (!running)
                elapsedFrames = 0;
            running = true;
        }
    }
    function publishFrame() {
        var phase = requestedOpen ? (running ? "open" : "settled") : "close";
        compositorFrame = phase + "|" + surfaceScale.toFixed(5) + "," + Math.max(0, Math.min(1, surfaceOpacity)).toFixed(5);
    }
    function spring(value, velocity, target, frequency, seconds) {
        var displacement = value - target;
        var coefficient = velocity + frequency * displacement;
        var decay = Math.exp(-frequency * seconds);
        return [(displacement + coefficient * seconds) * decay + target,
                (velocity - frequency * coefficient * seconds) * decay];
    }
    function advance(seconds) {
        if (!running || seconds <= 0)
            return;
        var targetScale = requestedOpen ? 1 : closingScale;
        var targetOpacity = requestedOpen ? 1 : 0;
        var scale = spring(surfaceScale, scaleVelocity, targetScale, (requestedOpen ? 22 : 28) / durationFactor, seconds);
        var opacity = spring(surfaceOpacity, opacityVelocity, targetOpacity, (requestedOpen ? 40 : 35) / durationFactor, seconds);
        var contentSeconds = Math.max(0, seconds - revealDelay);
        revealDelay = Math.max(0, revealDelay - seconds);
        var content = spring(contentOpacity, contentVelocity, targetOpacity, (requestedOpen ? 28 : 40) / durationFactor, contentSeconds);
        surfaceScale = scale[0];
        scaleVelocity = scale[1];
        surfaceOpacity = opacity[0];
        opacityVelocity = opacity[1];
        contentOpacity = content[0];
        contentVelocity = content[1];
        if (Math.abs(surfaceScale - targetScale) < 0.0003 && Math.abs(scaleVelocity) < 0.005
                && Math.abs(surfaceOpacity - targetOpacity) < 0.002 && Math.abs(opacityVelocity) < 0.03
                && Math.abs(contentOpacity - targetOpacity) < 0.002 && Math.abs(contentVelocity) < 0.03) {
            surfaceScale = targetScale;
            surfaceOpacity = contentOpacity = targetOpacity;
            scaleVelocity = opacityVelocity = contentVelocity = 0;
            finish();
        }
        publishFrame();
    }
    function finish() {
        running = false;
        if (closeRequested && !requestedOpen) {
            closeRequested = false;
            closed();
        }
    }
    FrameAnimation {
        objectName: "motionFrames"
        running: motion.running
        onTriggered: {
            var elapsed = elapsedTime;
            // A cold window or a long frame must not skip the initial reveal.
            motion.advance(Math.min(1 / 30, Math.max(0, elapsed - motion.elapsedFrames)));
            motion.elapsedFrames = elapsed;
        }
    }
}
