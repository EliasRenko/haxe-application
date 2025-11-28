package display;

import display.BitmapFont;

/**
 * Text - A text string instance that uses a shared BitmapFont for rendering
 * 
 * Lightweight text object that manages tiles for a specific string.
 * Multiple Text instances can share the same BitmapFont for efficient batching.
 */
class Text {
    
    public var text(get, set):String;

    public var font:BitmapFont;
    private var textString:String = "";
    private var charTiles:Array<Int> = [];  // Track tile IDs for each character
    
    // Position and transform
    public var x(get, set):Float;
    public var y(get, set):Float;
    public var width:Float = 0;
    public var height:Float = 0;
    public var visible:Bool = true;

    private var _x:Float = 0;
    private var _y:Float = 0;
    
    /**
     * Create a new Text instance
     * @param font The BitmapFont to use for rendering
     * @param text Initial text string (optional)
     */
    public function new(font:BitmapFont, text:String = "", x:Float = 0, y:Float = 0) {
        this._x = x;
        this._y = y;

        if (font != null) {
            this.font = font;
        }

        if (text.length > 0) {
            setText(text);
        }
    }
    
    /**
     * Set the text to display
     * @param text The string to display
     */
    public function setText(text:String):Void {
        //if (text == textString) return; // No change

        textString = text;

        if (font == null) {
            trace("Text: Error - Cannot set text because font is null");
            return;
        }
        
        updateTiles();
        
        trace("Text: Set text to \"" + text + "\" (" + charTiles.length + " characters, width=" + width + ", height=" + height + ")");
    }

    public function updateTiles():Void {
        
        // Clear existing character tiles from the font batch
        for (tileId in charTiles) {
            font.removeTile(tileId);
        }
        charTiles = [];
        
        // Create tiles for each character
        var cursorX:Float = _x;
        var cursorY:Float = _y;
        var maxWidth:Float = 0;  // Track maximum line width
        var currentLineWidth:Float = 0;  // Track current line width
        var lineCount:Int = 1;  // Track number of lines
        
        for (i in 0...text.length) {
            var charCode = text.charCodeAt(i);
            
            // Handle newlines
            if (charCode == 10) { // '\n'
                if (currentLineWidth > maxWidth) maxWidth = currentLineWidth;
                currentLineWidth = 0;
                lineCount++;
                cursorX = x;
                cursorY += font.fontData.lineHeight;
                continue;
            }
            
            // Get character data
            var fontChar = font.getCharData(charCode);
            if (fontChar == null) {
                trace("Text: Warning - Character '" + text.charAt(i) + "' (code=" + charCode + ") not found in font");
                cursorX += font.fontData.lineHeight / 2;
                currentLineWidth += font.fontData.lineHeight / 2;
                continue;
            }
            
            // Get the region ID for this character
            var regionId = font.getRegionForChar(charCode);
            if (regionId == -1) {
                trace("Text: Warning - Region not found for character '" + text.charAt(i) + "' (code=" + charCode + ")");
                cursorX += fontChar.xadvance;
                currentLineWidth += fontChar.xadvance;
                continue;
            }
            
            // Calculate position with offsets
            var tileX = cursorX + fontChar.xoffset;
            var tileY = cursorY + fontChar.yoffset;
            
            // Add tile to the font batch
            var tileId = font.addTile(
                tileX,
                tileY,
                fontChar.width,
                fontChar.height,
                regionId
            );
            
            charTiles.push(tileId);
            
            // Advance cursor
            cursorX += fontChar.xadvance;
            currentLineWidth += fontChar.xadvance;
        }
        
        // Update width and height
        if (currentLineWidth > maxWidth) maxWidth = currentLineWidth;
        width = maxWidth;
        height = lineCount * font.fontData.lineHeight;
    }
    
    /**
     * Get the current text string
     */
    public function getText():String {
        return textString;
    }
    
    /**
     * Update the position of all character tiles
     * Call this after changing x or y
     */
    public function updatePosition():Void {
        // Regenerate text at new position
        var currentText = textString;
        //textString = ""; // Force regeneration
        setText(currentText);
    }
    

    
    /**
     * Remove this text from the font batch
     */
    public function remove():Void {
        for (tileId in charTiles) {
            font.removeTile(tileId);
        }
        charTiles = [];
        textString = "";
    }

    public function dispose():Void {
        remove();
    }
    
    /**
     * Get the width of the current text in pixels
     */
    public function getTextWidth():Float {
        return font.measureTextWidth(textString);
    }
    
    /**
     * Get the height of the current text in pixels
     */
    public function getTextHeight():Float {
        return font.measureTextHeight(textString);
    }

    public function get_text():String {
        return textString;
    }

    public function set_text(value:String):String {
        textString = value;
        updatePosition();
        return textString;
    }

    public function set_visible(value:Bool):Bool {
        visible = value;
        
        // Update visibility of all character tiles
        for (tileId in charTiles) {
            var tile = font.getTile(tileId);
            if (tile != null) {
                tile.visible = value;
            }
        }
        
        // Mark buffers as dirty to update rendering
        font.needsBufferUpdate = true;

        return visible;
    }

    public function get_visible():Bool {
        return visible;
    }

    public function set_x(value:Float):Float {
        _x = value;
        updatePosition();
        return _x;
    }

    public function get_x():Float {
        return _x;
    }

    public function set_y(value:Float):Float {
        _y = value;
        updatePosition();
        return _y;
    }

    public function get_y():Float {
        return _y;
    }
}
