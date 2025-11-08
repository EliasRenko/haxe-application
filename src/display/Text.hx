package display;

import display.BitmapFont;

/**
 * Text - A text string instance that uses a shared BitmapFont for rendering
 * 
 * Lightweight text object that manages tiles for a specific string.
 * Multiple Text instances can share the same BitmapFont for efficient batching.
 */
class Text {
    
    public var font:BitmapFont;
    private var textString:String = "";
    private var charTiles:Array<Int> = [];  // Track tile IDs for each character
    
    // Position and transform
    public var x:Float = 0;
    public var y:Float = 0;
    
    /**
     * Create a new Text instance
     * @param font The BitmapFont to use for rendering
     * @param text Initial text string (optional)
     */
    public function new(font:BitmapFont, text:String = "") {
        this.font = font;
        
        if (text.length > 0) {
            setText(text);
        }
    }
    
    /**
     * Set the text to display
     * @param text The string to display
     */
    public function setText(text:String):Void {
        if (text == textString) return; // No change
        
        textString = text;
        
        // Clear existing character tiles from the font batch
        for (tileId in charTiles) {
            font.removeTile(tileId);
        }
        charTiles = [];
        
        // Create tiles for each character
        var cursorX:Float = x;
        var cursorY:Float = y;
        
        for (i in 0...text.length) {
            var charCode = text.charCodeAt(i);
            
            // Handle newlines
            if (charCode == 10) { // '\n'
                cursorX = x;
                cursorY += font.fontData.lineHeight;
                continue;
            }
            
            // Get character data
            var fontChar = font.getCharData(charCode);
            if (fontChar == null) {
                trace("Text: Warning - Character '" + text.charAt(i) + "' (code=" + charCode + ") not found in font");
                cursorX += font.fontData.lineHeight / 2; // Skip unknown char
                continue;
            }
            
            // Get the region ID for this character
            var regionId = font.getRegionForChar(charCode);
            if (regionId == -1) {
                trace("Text: Warning - Region not found for character '" + text.charAt(i) + "' (code=" + charCode + ")");
                cursorX += fontChar.xadvance;
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
        }
        
        trace("Text: Set text to \"" + text + "\" (" + charTiles.length + " characters)");
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
        textString = ""; // Force regeneration
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
}