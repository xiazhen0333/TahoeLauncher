// SPDX-License-Identifier: GPL-2.0-or-later
"use strict";

class TahoeLauncherMotion {
    constructor() {
        this.windows = new Map();
        this.phases = new Map();
        this.watched = new Set();
        this.applyingFrames = new Set();
        effect.animationEnded.connect(this.finished.bind(this));
        effects.windowAdded.connect(this.added.bind(this));
        effects.windowClosed.connect(this.closed.bind(this));
        effects.windowDeleted.connect(this.deleted.bind(this));
        effects.stackingOrder.forEach(this.watch.bind(this));
    }
    marker(window) {
        if (!/(^|\s)(?:org\.kde\.)?plasmashell(?:\s|$)/.test(window.windowClass)) return null;
        const match = /^TahoeLauncher Motion v([234])\|([\d.]+),([\d.]+),(-?\d+)(?:\|(open|close|settled))?(?:\|([\d.]+),([\d.]+))?(?:$|\s)/.exec(window.caption);
        if (!match) return null;
        if (match[1] !== "2" && !match[5]) return null;
        const x = Number(match[2]), y = Number(match[3]), travel = Number(match[4]);
        if (!Number.isFinite(x) || !Number.isFinite(y) || x < 0 || x > 1 || y < 0 || y > 1 || Math.abs(travel) > 10) return null;
        const frame = match[1] === "4", scale = Number(match[6]), opacity = Number(match[7]);
        if (frame && (!match[6] || !match[7] || !Number.isFinite(scale) || scale < 0.8 || scale > 1.2 || !Number.isFinite(opacity) || opacity < 0 || opacity > 1)) return null;
        return { x: x, y: y, travel: travel, phase: match[5], frame: frame, scale: scale, opacity: opacity };
    }
    watch(window) {
        if (!/plasmashell/.test(window.windowClass) || this.watched.has(window)) return;
        this.watched.add(window);
        window.windowDamaged.connect(w => {
            const marker = this.marker(w);
            if (!marker || !marker.phase || !w.visible) return;
            if (marker.frame) this.applyFrame(w, marker);
            else if (marker.phase === "settled") this.release(w);
            else this.transition(w, marker.phase === "open");
        });
        window.windowHiddenChanged.connect(w => {
            const marker = this.marker(w);
            if (!marker) return;
            if (marker.phase && !w.visible) {
                this.release(w);
                this.phases.delete(w);
            }
            else if (marker.frame) this.applyFrame(w, marker);
            else this.transition(w, w.visible);
        });
    }
    added(window) {
        this.watch(window);
        const marker = this.marker(window);
        if (window.visible && marker) {
            if (marker.frame) this.applyFrame(window, marker);
            else this.transition(window, true);
        }
    }
    closed(window) {
        const marker = this.marker(window);
        if (!marker) return;
        if (marker.phase) {
            this.release(window);
            this.phases.delete(window);
        }
        else this.transition(window, false);
    }
    translation(window, marker, scale) {
        return {
            value1: (marker.x - 0.5) * window.width * (1 - scale),
            value2: (marker.y - 0.5) * window.height * (1 - scale) + marker.travel
        };
    }
    applyFrame(window, marker) {
        // Creating or retargeting an animation can synchronously damage the window.
        if (this.applyingFrames.has(window)) return;
        this.applyingFrames.add(window);
        try {
            this.updateFrame(window, marker);
        } finally {
            this.applyingFrames.delete(window);
        }
    }
    updateFrame(window, marker) {
        // The fitted spring crosses 1 during its rebound. Only settled ends it.
        if (marker.phase === "settled" || effects.hasActiveFullScreenEffect) {
            this.release(window);
            return;
        }
        // Qt supplies the spring sample; KWin transforms content and blur together.
        const progress = Math.max(0, Math.min(1, (1 - marker.scale) / 0.09));
        const translation = this.translation(window, marker, marker.scale);
        translation.value2 = (marker.y - 0.5) * window.height * (1 - marker.scale) + marker.travel * progress;
        const values = [marker.scale, marker.opacity, translation];
        const types = [Effect.Scale, Effect.Opacity, Effect.Translation];
        let state = this.windows.get(window);
        if (!state) {
            effect.grab(window, Effect.WindowAddedGrabRole, true);
            effect.grab(window, Effect.WindowClosedGrabRole, true);
            window.setData(Effect.WindowForceBlurRole, true);
            window.setData(Effect.WindowForceBackgroundContrastRole, true);
            state = { ids: [], mapped: true, frame: true };
            this.windows.set(window, state);
        }
        for (let i = 0; i < 3; ++i) {
            if (!state.ids[i] || !retarget(state.ids[i], values[i], 1)) {
                state.ids[i] = set({ window: window, type: types[i], from: values[i], to: values[i], duration: 1, curve: QEasingCurve.Linear, keepAlive: false })[0];
            }
            // Hold this exact frame until Qt publishes the next spring sample.
            freezeInTime(state.ids[i], 1);
        }
    }
    transition(window, opening) {
        const marker = this.marker(window);
        if (!marker || effects.hasActiveFullScreenEffect) return;
        if (marker.phase) {
            if (this.phases.get(window) === opening) return;
            this.phases.set(window, opening);
        }
        let state = this.windows.get(window);
        if (state && state.opening === opening) return;
        effect.grab(window, Effect.WindowAddedGrabRole, true);
        effect.grab(window, Effect.WindowClosedGrabRole, true);
        window.setData(Effect.WindowForceBlurRole, true);
        window.setData(Effect.WindowForceBackgroundContrastRole, true);
        const duration = Math.max(1, animationTime(opening ? 260 : 180));
        const opacityDuration = Math.max(1, animationTime(opening ? 130 : 180));
        const targetScale = opening ? 1 : 0.96;
        const targetTranslation = opening ? { value1: 0, value2: 0 } : this.translation(window, marker, targetScale);
        const targets = [targetScale, opening ? 1 : 0, targetTranslation];
        const durations = [duration, opacityDuration, duration];
        if (state) {
            // KWin samples each current value before changing its target.
            state.opening = opening;
            state.pending = 0;
            const types = [Effect.Scale, Effect.Opacity, Effect.Translation];
            const neutral = [1, 1, { value1: 0, value2: 0 }];
            for (let i = 0; i < 3; ++i) {
                if (!retarget(state.ids[i], targets[i], durations[i])) {
                    const start = marker.phase ? set : animate;
                    state.ids[i] = start({ window: window, type: types[i], from: neutral[i], to: targets[i], duration: durations[i], keepAlive: false, curve: opening ? QEasingCurve.OutCubic : QEasingCurve.InCubic })[0];
                }
                state.pending++;
            }
            return;
        }
        state = { opening: opening, pending: 3, ids: [], mapped: !!marker.phase };
        this.windows.set(window, state);
        const fromScale = opening ? 0.94 : 1;
        const fromTranslation = opening ? this.translation(window, marker, fromScale) : { value1: 0, value2: 0 };
        const start = marker.phase ? set : animate;
        state.ids = start({
            window: window,
            duration: duration,
            curve: opening ? QEasingCurve.OutCubic : QEasingCurve.InCubic,
            keepAlive: !marker.phase,
            animations: [
                { type: Effect.Scale, from: fromScale, to: targetScale },
                { type: Effect.Opacity, from: opening ? 0 : 1, to: opening ? 1 : 0, duration: opacityDuration },
                { type: Effect.Translation, from: fromTranslation, to: targetTranslation }
            ]
        });
    }
    finished(window) {
        const state = this.windows.get(window);
        if (!state || state.frame || --state.pending > 0) return;
        // A mapped close holds opacity at zero until Plasma actually hides it.
        if (state.mapped && !state.opening) return;
        this.release(window);
    }
    release(window) {
        const state = this.windows.get(window);
        if (!state) return;
        this.windows.delete(window);
        if (state.mapped) state.ids.forEach(id => cancel(id));
        window.setData(Effect.WindowForceBlurRole, null);
        window.setData(Effect.WindowForceBackgroundContrastRole, null);
        effect.ungrab(window, Effect.WindowAddedGrabRole);
        effect.ungrab(window, Effect.WindowClosedGrabRole);
    }
    deleted(window) {
        this.release(window);
        this.phases.delete(window);
        this.watched.delete(window);
    }
}
new TahoeLauncherMotion();
