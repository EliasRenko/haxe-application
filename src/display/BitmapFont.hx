package display;

import ProgramInfo;
import Texture;
import loaders.FontData;
import display.TileBatch;

/**
 * BitmapFont - Manages a bitmap font atlas and shared rendering
 * 
 * Extends TileBatch to batch multiple Text instances using the same font.
 * Handles font atlas regions and character metrics.
 */
class BitmapFont extends TileBatch {
    
    public var fontData:FontData;
    private var charCodeToRegion:Map<Int, Int> = new Map();  // Map character code to region ID
    
    /**
     * Create a new BitmapFont
     * @param programInfo Shader program (use mono shader for 1bpp fonts)
     * @param texture Font texture atlas
     * @param fontData Font data loaded by FontLoader
     */
    public function new(programInfo:ProgramInfo, texture:Texture, fontData:FontData) {
        super(programInfo, texture);
        this.fontData = fontData;
        
        trace("BitmapFont: Created font '" + fontData.name + "' size=" + fontData.size);
        
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
        
        trace("BitmapFont: Defined " + regionCount + " character regions");
    }
    
    /**
     * Get the region ID for a character code
     * @param charCode Character code
     * @return Region ID, or -1 if not found
     */
    public function getRegionForChar(charCode:Int):Int {
        var regionId = charCodeToRegion.get(charCode);
        return regionId != null ? regionId : -1;
    }
    
    /**
     * Get character data for a character code
     * @param charCode Character code
     * @return FontChar data, or null if not found
     */
    public function getCharData(charCode:Int):loaders.FontData.FontChar {
        return fontData.chars.get(charCode);
    }
    
    /**
     * Calculate the width of a text string using this font
     * @param text Text string
     * @return Width in pixels
     */
    public function measureTextWidth(text:String):Float {
        var width:Float = 0;
        var currentLineWidth:Float = 0;
        
        for (i in 0...text.length) {
            var charCode = text.charCodeAt(i);
            
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
     * Calculate the height of a text string using this font
     * @param text Text string
     * @return Height in pixels
     */
    public function measureTextHeight(text:String):Float {
        var lines = 1;
        for (i in 0...text.length) {
            if (text.charCodeAt(i) == 10) lines++;
        }
        return lines * fontData.lineHeight;
    }
}
