package gui;

import display.Tile;
import gui.ControlEventType;

/**
 * PropertyGrid — a scrollable name/value editor.
 *
 * Supports string, float, int, bool, and enum (dropdown) properties.
 * Fires ON_PROPERTY_CHANGE on itself whenever any row value changes.
 * Query `lastChangedName` and `lastChangedValue` in the listener.
 *
 * Usage:
 *   var grid = new PropertyGrid(240, 200, x, y);
 *   canvas.addControl(grid);
 *   grid.addString("Name",   "Player");
 *   grid.addFloat("Speed",   5.0);
 *   grid.addInt("Health",    100);
 *   grid.addBool("Visible",  true);
 *   grid.addEnum("Mode",     "Walk", ["Walk", "Run", "Fly"]);
 *   grid.addListener(onChanged, ON_PROPERTY_CHANGE);
 *
 *   function onChanged(ctrl:Control, type:UInt):Void {
 *       var g = cast(ctrl, PropertyGrid);
 *       trace(g.lastChangedName + " = " + Std.string(g.lastChangedValue));
 *   }
 *
 * Note: addString / addFloat / etc. must be called AFTER canvas.addControl(grid).
 */
class PropertyGrid extends Container<Control> {

    public static inline var ROW_HEIGHT:Int    = 26;
    public static inline var PAD_X:Int         = 4;
    public static inline var PAD_Y:Int         = 4;
    /** Fraction of the row width used by the name label column. */
    public static inline var LABEL_RATIO:Float = 0.45;

    // ── Public state ──────────────────────────────────────────────────────────

    /** Name of the most recently changed property. */
    public var lastChangedName:String   = '';

    /** Value of the most recently changed property (String, Float, Int, or Bool). */
    public var lastChangedValue:Dynamic = null;

    // ── Privates ──────────────────────────────────────────────────────────────

    private var __panel:Panel;
    private var __scroll:ScrollableContainer;
    private var __rows:Array<PropertyRow> = [];

    public function new(width:Float, height:Float, x:Float, y:Float) {
        super(width, height, x, y);
        __type = 'propertygrid';
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override function init():Void {
        __panel  = new Panel(__width, __height, 0, 0);
        __scroll = new ScrollableContainer(
            __width  - PAD_X * 2,
            __height - PAD_Y * 2,
            PAD_X, PAD_Y);

        __addControl(__panel);
        __addControl(__scroll);

        super.init();
    }

    override function update():Void {
        if (__scroll != null && __scroll.hitTest()) __scroll.update();
    }

    // ── Public API ────────────────────────────────────────────────────────────

    /** Add a string property backed by a text field. */
    public function addString(name:String, value:String):Void {
        __addRow(new PropertyRow(name, STRING, value, null, __rows.length, __rowWidth()));
    }

    /** Add a float property (restricts input to numeric characters). */
    public function addFloat(name:String, value:Float):Void {
        __addRow(new PropertyRow(name, FLOAT, Std.string(value), null, __rows.length, __rowWidth()));
    }

    /** Add an int property (restricts input to digits). */
    public function addInt(name:String, value:Int):Void {
        __addRow(new PropertyRow(name, INT, Std.string(value), null, __rows.length, __rowWidth()));
    }

    /** Add a bool property backed by a checkbox. */
    public function addBool(name:String, value:Bool):Void {
        __addRow(new PropertyRow(name, BOOL, value ? "true" : "false", null, __rows.length, __rowWidth()));
    }

    /** Add an enum property backed by a dropdown. */
    public function addEnum(name:String, value:String, options:Array<String>):Void {
        __addRow(new PropertyRow(name, ENUM, value, options, __rows.length, __rowWidth()));
    }

    /**
     * Get the current value of a named property.
     * Returns Float for float rows, Int for int rows, Bool for bool rows,
     * String for string/enum rows, and null if the name is not found.
     */
    public function getValue(name:String):Dynamic {
        for (row in __rows) {
            if (row.propName == name) return row.getValue();
        }
        return null;
    }

    /**
     * Set the value of a named property programmatically.
     * Does NOT fire ON_PROPERTY_CHANGE.
     */
    public function setValue(name:String, value:Dynamic):Void {
        for (row in __rows) {
            if (row.propName == name) {
                row.setValue(Std.string(value));
                return;
            }
        }
    }

    /** Remove all property rows. */
    public function clear():Void {
        for (row in __rows) {
            if (__scroll != null) __scroll.removeControl(row);
        }
        __rows = [];
    }

    // ── Internals ─────────────────────────────────────────────────────────────

    private function __addRow(row:PropertyRow):Void {
        if (__scroll == null) return;
        __rows.push(row);
        __scroll.addControl(row);
        row.setOnChange(__onRowChanged);
    }

    private function __onRowChanged(row:PropertyRow):Void {
        lastChangedName  = row.propName;
        lastChangedValue = row.getValue();
        dispatchEvent(this, ON_PROPERTY_CHANGE);
    }

    private inline function __rowWidth():Float {
        return __width - PAD_X * 2 - ScrollableContainer.HANDLE_W;
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// PropertyType
// ─────────────────────────────────────────────────────────────────────────────

private enum abstract PropertyType(Int) {
    var STRING;
    var FLOAT;
    var INT;
    var BOOL;
    var ENUM;
}

// ─────────────────────────────────────────────────────────────────────────────
// PropertyTextField — extends TextField to dispatch ON_TEXT_INPUT on every
// keystroke so PropertyRow can detect changes without polling.
// ─────────────────────────────────────────────────────────────────────────────

private class PropertyTextField extends TextField {

    public function new(text:String, width:Float, x:Float, y:Float) {
        super(text, width, x, y);
    }

    override public function onTextInput():Void {
        super.onTextInput();
        dispatchEvent(this, ON_TEXT_INPUT);
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// PropertyRow — one name/value row inside the scrollable body.
// ─────────────────────────────────────────────────────────────────────────────

private class PropertyRow extends Container<Control> {

    public var propName:String;

    private var __nameLabel:Label;
    private var __propType:PropertyType;
    private var __textField:Null<PropertyTextField> = null;
    private var __checkbox:Null<Checkbox>           = null;
    private var __dropdown:Null<Dropdown>           = null;
    private var __bgTile:Null<Tile>                 = null;
    private var __even:Bool;
    private var __enumOptions:Null<Array<String>>   = null;
    private var __onChangeCb:Null<PropertyRow -> Void> = null;

    public function new(name:String, type:PropertyType, initValue:String,
                        options:Array<String>, rowIndex:Int, rowWidth:Float) {
        super(rowWidth, PropertyGrid.ROW_HEIGHT, 0, rowIndex * PropertyGrid.ROW_HEIGHT);
        __type        = 'propertyrow';
        propName      = name;
        __propType    = type;
        __even        = (rowIndex % 2 == 0);
        __enumOptions = options;

        var labelWidth:Float = rowWidth * PropertyGrid.LABEL_RATIO;
        var valueX:Float     = labelWidth;
        var valueWidth:Float = rowWidth - labelWidth;
        var valueY:Int       = Std.int((PropertyGrid.ROW_HEIGHT - 24) / 2);

        // Queue name label (left column) — Y will be centred in init() once font is known.
        __nameLabel = new Label(name, PropertyGrid.PAD_X, 0);
        @:privateAccess __controls.add(cast __nameLabel);

        // Queue value control (right column).
        switch (type) {
            case STRING:
                __textField = new PropertyTextField(initValue, valueWidth, valueX, valueY);
                @:privateAccess __controls.add(cast __textField);

            case FLOAT:
                __textField = new PropertyTextField(initValue, valueWidth, valueX, valueY);
                __textField.restriction = '0123456789.-';
                @:privateAccess __controls.add(cast __textField);

            case INT:
                __textField = new PropertyTextField(initValue, valueWidth, valueX, valueY);
                __textField.restriction = '0123456789-';
                @:privateAccess __controls.add(cast __textField);

            case BOOL:
                __checkbox = new Checkbox(initValue == "true", valueX + 2, valueY);
                @:privateAccess __controls.add(cast __checkbox);

            case ENUM:
                __dropdown = new Dropdown(valueWidth, valueX, valueY);
                if (options != null) {
                    for (opt in options) __dropdown.addItem(opt);
                    var idx = options.indexOf(initValue);
                    if (idx >= 0) __dropdown.selectIndex(idx);
                }
                @:privateAccess __controls.add(cast __dropdown);
        }
    }

    override function init():Void {
        // Even-row background tile for a subtle alternating stripe.
        if (__even) {
            __bgTile          = new Tile(null);
            __bgTile.width    = __width;
            __bgTile.height   = PropertyGrid.ROW_HEIGHT;
            __bgTile.regionId = ____canvas.sets.get('panel_4');
            ____canvas.tilemap.addTileInstance(__bgTile);
        }

        super.init(); // initialises all queued children

        // Centre the name label vertically now that the font height is known.
        __nameLabel.y = Std.int((PropertyGrid.ROW_HEIGHT - ____canvas.font.fontData.lineHeight) / 2);

        // Wire change listeners after children are active.
        if (__textField != null)
            __textField.addListener(__onValueChanged, ON_TEXT_INPUT);
        if (__checkbox != null)
            __checkbox.addListener(__onValueChanged, LEFT_CLICK);
        if (__dropdown != null)
            __dropdown.addListener(__onValueChanged, ON_ITEM_CLICK);
    }

    override function release():Void {
        if (__bgTile != null) {
            ____canvas.tilemap.removeTileInstance(__bgTile);
            __bgTile = null;
        }
        super.release();
    }

    override function update():Void {
        for (control in @:privateAccess __controls) {
            if (control.hitTest()) {
                control.update();
                return;
            }
        }
    }

    // ── API called by PropertyGrid ─────────────────────────────────────────

    public function setOnChange(cb:PropertyRow -> Void):Void {
        __onChangeCb = cb;
    }

    public function getValue():Dynamic {
        return switch (__propType) {
            case STRING: __textField != null ? __textField.text : '';
            case FLOAT:  __textField != null ? Std.parseFloat(__textField.text) : 0.0;
            case INT:    __textField != null ? Std.parseInt(__textField.text)   : 0;
            case BOOL:   __checkbox  != null ? __checkbox.value                 : false;
            case ENUM:   __dropdown  != null ? __dropdown.selectedValue         : '';
        };
    }

    public function setValue(v:String):Void {
        switch (__propType) {
            case STRING | FLOAT | INT:
                if (__textField != null) __textField.text = v;
            case BOOL:
                if (__checkbox != null) __checkbox.value = (v == "true");
            case ENUM:
                if (__dropdown != null && __enumOptions != null) {
                    var idx = __enumOptions.indexOf(v);
                    if (idx >= 0) __dropdown.selectIndex(idx);
                }
        }
    }

    // ── Graphics positioning ───────────────────────────────────────────────

    override function __setGraphicX():Void {
        if (__bgTile != null) __bgTile.x = __x + ____offsetX;
    }

    override function __setGraphicY():Void {
        if (__bgTile != null) __bgTile.y = __y + ____offsetY;
    }

    override function set_visible(value:Bool):Bool {
        if (__bgTile != null) __bgTile.visible = value;
        return super.set_visible(value);
    }

    // ── Internal listener ──────────────────────────────────────────────────

    private function __onValueChanged(ctrl:Control, type:UInt):Void {
        if (__onChangeCb != null) __onChangeCb(this);
    }
}
