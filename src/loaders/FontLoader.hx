package loaders;

import haxe.Json;
import loaders.FontData;

/**
 * Loads BMFont JSON format and converts it to FontData
 */
class FontLoader {
    
    /**
     * Parse BMFont JSON and return FontData
     * @param jsonText The JSON string from the font file
     * @return FontData structure with all font information
     */
    public static function load(jsonText:String):FontData {
        trace("FontLoader: Parsing font JSON...");
        
        // Parse JSON
        var json:Dynamic = Json.parse(jsonText);
        var fontJson = json.font;
        
        // Extract common font info
        var info = fontJson.info;
        var common = fontJson.common;
        var pages = fontJson.pages;
        
        // Create FontData structure
        var fontData:FontData = {
            name: info._face,
            size: Std.parseInt(info._size),
            lineHeight: Std.parseInt(common._lineHeight),
            base: Std.parseInt(common._base),
            textureWidth: Std.parseInt(common._scaleW),
            textureHeight: Std.parseInt(common._scaleH),
            textureName: pages.page._file,
            chars: new Map<Int, FontChar>()
        };
        
        trace("FontLoader: Loading font '" + fontData.name + "' size=" + fontData.size);
        trace("  Line height: " + fontData.lineHeight + ", Base: " + fontData.base);
        trace("  Texture: " + fontData.textureName + " (" + fontData.textureWidth + "x" + fontData.textureHeight + ")");
        
        // Parse characters
        var chars = fontJson.chars.char;
        var charCount = 0;
        
        for (charData in cast(chars, Array<Dynamic>)) {
            var charId = Std.parseInt(charData._id);
            
            var fontChar:FontChar = {
                id: charId,
                x: Std.parseInt(charData._x),
                y: Std.parseInt(charData._y),
                width: Std.parseInt(charData._width),
                height: Std.parseInt(charData._height),
                xoffset: Std.parseInt(charData._xoffset),
                yoffset: Std.parseInt(charData._yoffset),
                xadvance: Std.parseInt(charData._xadvance)
            };
            
            fontData.chars.set(charId, fontChar);
            charCount++;
        }
        
        trace("FontLoader: Loaded " + charCount + " characters");
        
        return fontData;
    }
    
    /**
     * Get printable character from character code for debugging
     */
    public static function getCharString(charCode:Int):String {
        if (charCode == 32) return "[SPACE]";
        if (charCode < 32 || charCode > 126) return "[" + charCode + "]";
        return String.fromCharCode(charCode);
    }
}
