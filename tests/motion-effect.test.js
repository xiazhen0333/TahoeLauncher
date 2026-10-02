// SPDX-License-Identifier: GPL-2.0-or-later
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { buildRows } = require('../contents/ui/js/categoryRows.js');
class Signal {
    constructor() { this.handlers = []; }
    connect(fn) { this.handlers.push(fn); }
    emit(...args) { this.handlers.slice().forEach(fn => fn(...args)); }
}
function harness() {
    const running = new Map(), calls = [], grabs = new Map();
    let next = 0;
    const effect = {
        animationEnded: new Signal(),
        grab(w, role) { grabs.set(role, w); return true; },
        ungrab(w, role) { grabs.delete(role); }
    };
    const effects = { windowAdded: new Signal(), windowClosed: new Signal(), windowDeleted: new Signal(), stackingOrder: [], hasActiveFullScreenEffect: false };
    const context = { effect, effects, Effect: { Scale: 1, Opacity: 2, Translation: 3, WindowAddedGrabRole: 4, WindowClosedGrabRole: 5, WindowForceBlurRole: 6, WindowForceBackgroundContrastRole: 7 }, QEasingCurve: { OutCubic: 1, InCubic: 2 }, animationTime: n => n,
        animate(options) {
            calls.push(options);
            return (options.animations || [options]).map(settings => {
                const id = ++next;
                running.set(id, { ...settings, window: options.window });
                return id;
            });
        },
        set(options) {
            const ids = context.animate(options);
            ids.forEach(id => running.get(id).persistent = true);
            return ids;
        },
        cancel(id) { running.delete(id); },
        retarget(id, target, duration) {
            const current = running.get(id);
            if (!current) return false;
            calls.push({ retarget: id, target, duration });
            current.to = target;
            return true;
        }
    };
    vm.createContext(context);
    const code = fs.readFileSync('kwin/tahoelauncher-motion/contents/code/main.js', 'utf8');
    vm.runInContext(code.replace('new TahoeLauncherMotion();', 'globalThis.motion = new TahoeLauncherMotion();'), context);
    const window = (caption = 'TahoeLauncher Motion v2|0.25,1.0000,8', windowClass = 'plasmashell org.kde.plasmashell') => {
        const data = new Map();
        return { caption, windowClass, visible: true, width: 600, height: 500, windowHiddenChanged: new Signal(), windowDamaged: new Signal(), data,
            setData(role, value) { data.set(role, value); }
        };
    };
    const finish = (w, type) => {
        const entry = [...running].find(([, a]) => a.window === w && a.type === type);
        assert.ok(entry, 'expected a running animation');
        if (!entry[1].persistent) running.delete(entry[0]);
        effect.animationEnded.emit(w, 0);
    };
    return { context, effect, effects, running, calls, grabs, window, finish };
}
{
    const h = harness(), w = h.window('TahoeLauncher Motion v3|0.5,0.5,0|open');
    h.effects.windowAdded.emit(w);
    h.finish(w, h.context.Effect.Opacity);
    w.caption = 'TahoeLauncher Motion v3|0.5,0.5,0|close';
    w.windowDamaged.emit(w);
    assert.equal(h.calls.filter(x => x.retarget).length, 3, 'completed persistent channels still reverse');
    w.caption = 'TahoeLauncher Motion v3|0.5,0.5,0|open';
    w.windowDamaged.emit(w);
    assert.equal(h.calls.filter(x => x.retarget).length, 6, 'mapped reopening retargets the same window');
    w.caption = 'TahoeLauncher Motion v3|0.5,0.5,0|settled';
    w.windowDamaged.emit(w);
    assert.equal(h.running.size, 0, 'settled opening removes persistent transforms');
    const count = h.calls.length;
    w.windowDamaged.emit(w);
    assert.equal(h.calls.length, count, 'ordinary repaint must not restart settled opening');
    w.caption = 'TahoeLauncher Motion v3|0.5,0.5,0|close';
    w.windowDamaged.emit(w);
    for (const type of [h.context.Effect.Opacity, h.context.Effect.Scale, h.context.Effect.Translation]) h.finish(w, type);
    assert.equal(h.running.size, 3, 'completed close remains invisible until actual hide');
    assert.equal(w.data.get(h.context.Effect.WindowForceBlurRole), true);
    w.visible = false;
    w.windowHiddenChanged.emit(w);
    h.effects.windowClosed.emit(w);
    assert.equal(h.running.size, 0, 'actual hide cancels retained channels');
    assert.equal(h.grabs.size, 0);
    h.effects.windowDeleted.emit(w);
    assert.equal(h.context.motion.phases.size, 0);
}
{
    const h = harness();
    for (const w of [h.window('Other launcher'), h.window(undefined, 'some-other-app'), h.window('TahoeLauncher Motion v2|3,1,8')]) h.effects.windowAdded.emit(w);
    assert.equal(h.calls.length, 0, 'unrelated windows must not animate');
    const w = h.window();
    h.effects.windowAdded.emit(w);
    assert.equal(h.running.size, 3);
    assert.equal(w.data.get(h.context.Effect.WindowForceBlurRole), true);
    h.finish(w, h.context.Effect.Opacity);
    assert.equal(w.data.get(h.context.Effect.WindowForceBlurRole), true, 'short fade must not release blur while scaling');
    w.visible = false;
    w.windowHiddenChanged.emit(w);
    assert.equal(h.running.size, 3, 'an already finished opacity channel is recreated');
    assert.equal(h.calls.filter(x => x.retarget).length, 2, 'live scale and translation are retargeted');
    h.effects.windowClosed.emit(w);
    assert.equal(h.running.size, 3, 'duplicate close events must not stack animations');
    w.visible = true;
    w.windowHiddenChanged.emit(w);
    assert.equal(h.calls.filter(x => x.retarget).length, 5, 'reopening reuses all live channels');
    h.finish(w, h.context.Effect.Opacity);
    h.finish(w, h.context.Effect.Scale);
    assert.equal(w.data.get(h.context.Effect.WindowForceBlurRole), true);
    h.finish(w, h.context.Effect.Translation);
    assert.equal(w.data.get(h.context.Effect.WindowForceBlurRole), null);
    assert.equal(h.grabs.size, 0);
    assert.equal(h.context.motion.windows.size, 0);
    w.visible = false; w.windowHiddenChanged.emit(w);
    w.visible = true; w.windowHiddenChanged.emit(w);
    assert.equal(h.running.size, 3, 'reused windows must animate every show/hide');
    h.effects.windowDeleted.emit(w);
    assert.equal(h.context.motion.windows.size, 0);
    assert.equal(h.context.motion.watched.size, 2); // two still-live unrelated plasmashell windows
}
{
    const h = harness(), w = h.window();
    h.effects.hasActiveFullScreenEffect = true;
    h.effects.windowAdded.emit(w);
    assert.equal(h.running.size, 0);
    h.effects.hasActiveFullScreenEffect = false;
    w.windowHiddenChanged.emit(w);
    const first = h.calls[0].animations.find(a => a.type === h.context.Effect.Translation);
    assert.ok(Math.abs(first.from.value1 + 9) < 1e-9);
    assert.ok(Math.abs(first.from.value2 - 23) < 1e-9, 'scale origin and travel combine around the launcher button');
}
{
    assert.equal(buildRows([0, 3000], 5, {}).length, 3);
    const rows = buildRows([12, 3000], 5, { 1: true });
    assert.equal(rows.length, 603);
    assert.deepEqual(rows.at(-1), { kind: 'apps', category: 1, firstIndex: 2995 });
    assert.equal(buildRows([6], 4, { 0: true }).at(-1).firstIndex, 4);
}
console.log('PASS: KWin filtering, reuse, interruption, blur lifetime, cleanup and category row indexing');
