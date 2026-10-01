// SPDX-License-Identifier: GPL-2.0-or-later
"use strict";

class TahoeLauncherMotion {
    constructor() {
        this.windows = new Map();
        this.watched = new Set();
        effect.animationEnded.connect(this.finished.bind(this));
        effects.windowAdded.connect(this.added.bind(this));
        effects.windowClosed.connect(this.closed.bind(this));
        effects.windowDeleted.connect(this.deleted.bind(this));
        effects.stackingOrder.forEach(this.watch.bind(this));
    }
    marker(window) {
        if (!/(^|\s)(?:org\.kde\.)?plasmashell(?:\s|$)/.test(window.windowClass)) return null;
        const match = /^TahoeLauncher Motion v2\|([\d.]+),([\d.]+),(-?\d+)(?:$|\s)/.exec(window.caption);
        if (!match) return null;
        const x = Number(match[1]), y = Number(match[2]), travel = Number(match[3]);
        if (!Number.isFinite(x) || !Number.isFinite(y) || x < 0 || x > 1 || y < 0 || y > 1 || Math.abs(travel) > 10) return null;
        return { x: x, y: y, travel: travel };
    }
    watch(window) {
        if (!/plasmashell/.test(window.windowClass) || this.watched.has(window)) return;
        this.watched.add(window);
        window.windowHiddenChanged.connect(w => {
            if (this.marker(w)) this.transition(w, w.visible);
        });
    }
    added(window) {
        this.watch(window);
        if (window.visible && this.marker(window)) this.transition(window, true);
    }
    closed(window) {
        if (this.marker(window)) this.transition(window, false);
    }
    translation(window, marker, scale) {
        return {
            value1: (marker.x - 0.5) * window.width * (1 - scale),
            value2: (marker.y - 0.5) * window.height * (1 - scale) + marker.travel
        };
    }
    transition(window, opening) {
        const marker = this.marker(window);
        if (!marker || effects.hasActiveFullScreenEffect) return;
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
                    state.ids[i] = animate({ window: window, type: types[i], from: neutral[i], to: targets[i], duration: durations[i], curve: opening ? QEasingCurve.OutCubic : QEasingCurve.InCubic })[0];
                }
                state.pending++;
            }
            return;
        }
        state = { opening: opening, pending: 3, ids: [] };
        this.windows.set(window, state);
        const fromScale = opening ? 0.94 : 1;
        const fromTranslation = opening ? this.translation(window, marker, fromScale) : { value1: 0, value2: 0 };
        state.ids = animate({
            window: window,
            duration: duration,
            curve: opening ? QEasingCurve.OutCubic : QEasingCurve.InCubic,
            animations: [
                { type: Effect.Scale, from: fromScale, to: targetScale },
                { type: Effect.Opacity, from: opening ? 0 : 1, to: opening ? 1 : 0, duration: opacityDuration },
                { type: Effect.Translation, from: fromTranslation, to: targetTranslation }
            ]
        });
    }
    finished(window) {
        const state = this.windows.get(window);
        if (!state || --state.pending > 0) return;
        this.windows.delete(window);
        window.setData(Effect.WindowForceBlurRole, null);
        window.setData(Effect.WindowForceBackgroundContrastRole, null);
        effect.ungrab(window, Effect.WindowAddedGrabRole);
        effect.ungrab(window, Effect.WindowClosedGrabRole);
    }
    deleted(window) {
        this.windows.delete(window);
        this.watched.delete(window);
    }
}
new TahoeLauncherMotion();
