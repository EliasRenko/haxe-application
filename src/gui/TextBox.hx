package gui;

/**
 * TextBox — a read-only, scrollable text display.
 *
 * Suitable for consoles, logs, help text, or any large block of formatted text.
 * Lines are appended individually; when `autoScroll` is true the view jumps to
 * the bottom automatically.  A `maxLines` cap evicts the oldest lines so the
 * control is safe for long-running console output.
 *
 * Usage:
 *   var tb = new TextBox(400, 160, x, y);
 *   canvas.addControl(tb);
 *   tb.append("Hello world");
 *   tb.append("Second line");
 *   tb.clear();
 *
 * `appendLine` is an alias for `append`.
 */
class TextBox extends Container<Control> {

    /** When true, scrolls to the bottom every time a line is appended. */
    public var autoScroll:Bool = true;

    /** Maximum number of lines retained before oldest are evicted (0 = unlimited). */
    public var maxLines:Int = 200;

    /** Vertical pixels between lines. */
    public var lineSpacing:Int = 18;

    public static inline var PAD_X:Int = 4;
    public static inline var PAD_Y:Int = 4;

    // ── Privates ───────────────────────────────────────────────────────────────

    private var __panel:Panel;
    private var __scroll:ScrollableContainer;
    private var __lines:Array<Label> = [];

    public function new(width:Float, height:Float, x:Float, y:Float) {
        super(width, height, x, y);
        __type = 'textbox';
    }

    override function init():Void {
        __panel  = new Panel(__width, __height, 0, 0);
        __scroll = new ScrollableContainer(__width - PAD_X * 2, __height - PAD_Y * 2, PAD_X, PAD_Y);

        // Use Container.__addControl so the parent handles canvas/offset/init.
        __addControl(__panel);
        __addControl(__scroll);

        super.init();

        // Auto-detect line spacing from the font so this works with any bitmap font.
        if (____canvas != null && ____canvas.font != null) {
            lineSpacing = ____canvas.font.fontData.lineHeight;
        }
    }

    override function release():Void {
        super.release();
    }

    override function update():Void {
        if (__scroll != null && __scroll.hitTest()) __scroll.update();
    }

    // ── Public API ─────────────────────────────────────────────────────────────

    /** Append a single line of text. Alias: appendLine. */
    public function append(text:String):Void {
        if (maxLines > 0 && __lines.length >= maxLines) _evict();

        var lbl = new Label(text, 0, __lines.length * lineSpacing);
        __scroll.addControl(lbl);
        __lines.push(lbl);

        if (autoScroll) _scrollToBottom();
    }

    public inline function appendLine(text:String):Void {
        append(text);
    }

    /** Remove all lines. */
    public function clear():Void {
        var toRemove = __lines.copy();
        for (lbl in toRemove) __scroll.removeControl(lbl);
        __lines = [];
    }

    // ── Internals ──────────────────────────────────────────────────────────────

    private function _scrollToBottom():Void {
        var contentH = @:privateAccess __scroll.__contentHeight;
        var viewH    = __height - PAD_Y * 2;
        var target   = contentH - viewH;
        if (target > 0) @:privateAccess __scroll.set_scrollY(target);
    }

    private function _evict():Void {
        if (__lines.length == 0) return;
        var oldest = __lines.shift();
        __scroll.removeControl(oldest);
        for (lbl in __lines) lbl.y = lbl.y - lineSpacing;
    }
}
