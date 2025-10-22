package display;

import ProgramInfo;
import Texture;
import loaders.FontData;

/**
 * Text display object that renders text using a bitmap font
 * Uses TileBatch internally to efficiently render characters
 */
class Text extends TileBatch {
    
    private var fontData:FontData;
    private var textString:String = "";
    private var charTiles:Array<Int> = [];  // Track tile IDs for each character
    private var charCodeToRegion:Map<Int, Int> = new Map();  // Map character code to region ID
    
    /**
     * Create a new Text display object
     * @param programInfo Shader program (use mono shader for 1bpp fonts)
     * @param texture Font texture atlas
     * @param fontData Font data loaded by FontLoader
     */
    public function new(programInfo:ProgramInfo, texture:Texture, fontData:FontData) {
        super(programInfo, texture);
        this.fontData = fontData;
        
        trace("Text: Created with font '" + fontData.name + "' size=" + fontData.size);
        
        // Define regions for all font characters
        defineCharacterRegions();
    }
    
    /**
     * Define atlas regions for all characters in the font
     */
    private function defineCharacterRegions():Void {
        var regionCount = 0;
        
        for (charCode in fontData.chars.keys()) {
            var fontChar = fontData.chars.get(charCode);
            
            // Define region for this character
            var regionId = defineRegion(
                fontChar.x,
                fontChar.y,
                fontChar.width,
                fontChar.height
            );
            
            // Map character code to region ID for fast lookup
            charCodeToRegion.set(charCode, regionId);
            
            regionCount++;
        }
        
        trace("Text: Defined " + regionCount + " character regions");
    }
    
    /**
     * Set the text to display
     * @param text The string to display
     */
    public function setText(text:String):Void {
        if (text == textString) return; // No change
        
        textString = text;
        
        // Clear existing character tiles
        for (tileId in charTiles) {
            removeTile(tileId);
        }
        charTiles = [];
        
        // Create tiles for each character
        var cursorX:Float = 0;
        var cursorY:Float = 0;
        
        for (i in 0...text.length) {
            var charCode = text.charCodeAt(i);
            
            // Handle newlines
            if (charCode == 10) { // '\n'
                cursorX = 0;
                cursorY += fontData.lineHeight;
                continue;
            }
            
            // Get character data
            var fontChar = fontData.chars.get(charCode);
            if (fontChar == null) {
                trace("Text: Warning - Character '" + text.charAt(i) + "' (code=" + charCode + ") not found in font");
                cursorX += fontData.lineHeight / 2; // Skip unknown char
                continue;
            }
            
            // Get the region ID for this character using the character code
            var regionId = charCodeToRegion.get(charCode);
            if (regionId == null) {
                trace("Text: Warning - Region not found for character '" + text.charAt(i) + "' (code=" + charCode + ")");
                cursorX += fontChar.xadvance;
                continue;
            }
            
            // Calculate position with offsets
            var tileX = cursorX + fontChar.xoffset;
            var tileY = cursorY + fontChar.yoffset;
            
            // Add tile for this character
            var tileId = addTile(
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
     * Get the width of the current text in pixels
     */
    public function getTextWidth():Float {
        var width:Float = 0;
        var currentLineWidth:Float = 0;
        
        for (i in 0...textString.length) {
            var charCode = textString.charCodeAt(i);
            
            if (charCode == 10) { // '\n'
                if (currentLineWidth > width) width = currentLineWidth;
                currentLineWidth = 0;
                continue;
            }
            
            var fontChar = fontData.chars.get(charCode);
            if (fontChar != null) {
                currentLineWidth += fontChar.xadvance;
            }
        }
        
        if (currentLineWidth > width) width = currentLineWidth;
        return width;
    }
    
    /**
     * Get the height of the current text in pixels
     */
    public function getTextHeight():Float {
        var lines = 1;
        for (i in 0...textString.length) {
            if (textString.charCodeAt(i) == 10) lines++;
        }
        return lines * fontData.lineHeight;
    }
    
    override public function render(cameraMatrix:math.Matrix):Void {
        super.render(cameraMatrix);
    }
}