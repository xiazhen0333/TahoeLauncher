// SPDX-License-Identifier: GPL-2.0-or-later
import QtQuick

// Fitted to the supplied 60 fps recording; see docs/macos-motion.md.
Item {
    id: motion
    property bool requestedOpen: false
    property bool closeRequested: false
    property bool animationsEnabled: true
    property real durationFactor: 1
    readonly property real openingScale: 1.14
    readonly property real closingScale: 1.08
    property real surfaceScale: openingScale
    property real surfaceOpacity: 0
    readonly property real contentBlur: 1 - surfaceOpacity
    property real scaleVelocity: 0
    property real revealDelay: 0.03
    property real fadeElapsed: 0
    property real fadeFrom: 0
    property bool running: false
    property real elapsedFrames: 0
    property string compositorFrame: "close|1.14000,0.00000"
    readonly property bool settled: !running
    signal closed

    function prepare() {
        running = false;
        requestedOpen = false;
        closeRequested = false;
        surfaceScale = openingScale;
        surfaceOpacity = 0;
        scaleVelocity = 0;
        revealDelay = 0.03;
        fadeElapsed = 0;
        fadeFrom = 0;
        elapsedFrames = 0;
        publishFrame();
    }
    function open() {
        if (requestedOpen)
            return;
        requestedOpen = true;
        closeRequested = false;
        start();
        publishFrame();
    }
    function close() {
        if (closeRequested)
            return;
        requestedOpen = false;
        closeRequested = true;
        revealDelay = 0;
        start();
        publishFrame();
    }
    function start() {
        fadeFrom = surfaceOpacity;
        fadeElapsed = -revealDelay;
        revealDelay = 0;
        if (!animationsEnabled || durationFactor <= 0) {
            surfaceScale = requestedOpen ? 1 : closingScale;
            surfaceOpacity = requestedOpen ? 1 : 0;
            scaleVelocity = 0;
            finish();
        } else {
            if (!running)
                elapsedFrames = 0;
            running = true;
        }
    }
    function publishFrame() {
        var phase = requestedOpen ? (running ? "open" : "settled") : "close";
        compositorFrame = phase + "|" + surfaceScale.toFixed(5) + "," + surfaceOpacity.toFixed(5);
    }
    function spring(value, velocity, target, frequency, damping, seconds) {
        var displacement = value - target;
        var decay = Math.exp(-damping * frequency * seconds);
        if (damping === 1) {
            var coefficient = velocity + frequency * displacement;
            return [(displacement + coefficient * seconds) * decay + target,
                    (velocity - frequency * coefficient * seconds) * decay];
        }
        var damped = frequency * Math.sqrt(1 - damping * damping);
        var sine = Math.sin(damped * seconds);
        var cosine = Math.cos(damped * seconds);
        var c = (velocity + damping * frequency * displacement) / damped;
        return [target + decay * (displacement * cosine + c * sine),
                decay * (velocity * cosine - (damping * frequency * c + damped * displacement) * sine)];
    }
    function advance(seconds) {
        if (!running || seconds <= 0)
            return;
        if (!animationsEnabled || durationFactor <= 0) {
            start();
            publishFrame();
            return;
        }
        var targetScale = requestedOpen ? 1 : closingScale;
        var scale = spring(surfaceScale, scaleVelocity, targetScale,
                           (requestedOpen ? 23 : 20) / durationFactor,
                           requestedOpen ? 0.7 : 1, seconds);
        surfaceScale = scale[0];
        scaleVelocity = scale[1];
        fadeElapsed += seconds / durationFactor;
        var progress = Math.max(0, Math.min(1, fadeElapsed / (requestedOpen ? 0.1 : 0.092)));
        var eased = requestedOpen ? 1 - (1 - progress) * (1 - progress) : progress;
        surfaceOpacity = fadeFrom + ((requestedOpen ? 1 : 0) - fadeFrom) * eased;
        // A fully transparent close can hide immediately; opening keeps its rebound.
        if ((!requestedOpen && progress === 1)
                || (requestedOpen && progress === 1
                    && Math.abs(surfaceScale - 1) < 0.0005 && Math.abs(scaleVelocity) < 0.02)) {
            surfaceScale = targetScale;
            surfaceOpacity = requestedOpen ? 1 : 0;
            scaleVelocity = 0;
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
            // The analytic solution keeps wall-clock timing after a dropped frame.
            motion.advance(Math.max(0, elapsed - motion.elapsedFrames));
            motion.elapsedFrames = elapsed;
        }
    }
}
