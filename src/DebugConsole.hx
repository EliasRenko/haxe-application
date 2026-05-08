package;

import gui.Canvas;
import gui.TextBox;
import gui.Window;

/**
 * DebugConsole — an in-game console overlay.
 *
 * Displays all messages routed through `App.log` and Haxe `trace()` calls.
 * Toggle visibility with the grave key (~) in MenuState.
 */
class DebugConsole {

    // ── Layout constants ──────────────────────────────────────────────────────
    private static inline var WIDTH:Float  = 600;
    private static inline var HEIGHT:Float = 260;
    private static inline var STRIP_H:Int  = 28;
    private static inline var PAD:Int      = 8;

    // ── Public API ────────────────────────────────────────────────────────────

    public var visible(get, set):Bool;

    // ── Privates ──────────────────────────────────────────────────────────────
    private var __app:App;
    private var __window:Window;
    private var __textBox:TextBox;
    private var __prevTrace:Dynamic;
    private var __inTrace:Bool = false;

    public function new(app:App, canvas:Canvas) {
        __app = app;

        var ws = app.window.size;
        var wx = Math.round((ws.x - WIDTH)  / 2);
        var wy = Math.round((ws.y - HEIGHT) / 2);

        __window = new Window("Console", WIDTH, HEIGHT, wx, wy);
        canvas.addControl(__window);

        var tbH = HEIGHT - STRIP_H - PAD * 2;
        __textBox = new TextBox(WIDTH - PAD * 2, tbH, PAD, PAD);
        __textBox.autoScroll = true;
        __window.addControl(__textBox);

        // ── Hook into app.log ─────────────────────────────────────────────────
        __app.log.onMessage = function(msg:String) {
            __textBox.append(msg);
        };

        // ── Intercept Haxe trace() ────────────────────────────────────────────
        __prevTrace = haxe.Log.trace;
        haxe.Log.trace = function(v:Dynamic, ?info:haxe.PosInfos) {
            __prevTrace(v, info);
            if (__inTrace) return;
            __inTrace = true;
            var prefix = (info != null) ? info.fileName + ":" + info.lineNumber + ": " : "";
            __textBox.append(prefix + Std.string(v));
            __inTrace = false;
        };

        // ── Seed with existing log history ────────────────────────────────────
        var history = __app.log.logHistory;
        if (history != null && history.length > 0) {
            for (line in history.split("\n")) {
                if (line.length > 0) __textBox.append(line);
            }
        }
    }

    // ── Getters / setters ─────────────────────────────────────────────────────

    private function get_visible():Bool return __window.visible;

    private function set_visible(v:Bool):Bool {
        __window.visible = v;
        return v;
    }
}
