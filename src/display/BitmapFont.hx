package display;

import Texture;
import Renderer;
import loaders.FontData;
import display.IFontSource;
import display.ManagedTileBatch;
import display.Tile;
import display.ManagedTileBatch.AtlasRegion;

/**
 * BitmapFont - Manages a bitmap font atlas and character metrics.
 *
 * Uses a ManagedTileBatch to manage atlas regions, glyph tiles, and rendering.
 */
class BitmapFont implements IFontSource {

    public var fontData:FontData;
    public var tileBatch(default, null):ManagedTileBatch;
    public var atlasRegions(get, never):Map<Int, AtlasRegion>;

    private var charCodeToRegion:Map<Int, Int> = new Map();

    /**
     * Create a new BitmapFont.
     * @param renderer Renderer used to create the glyph batch
     * @param texture Font texture atlas
     * @param fontData Font data loaded by FontLoader
     */
    public function new(renderer:Renderer, texture:Texture, fontData:FontData) {
        this.fontData = fontData;
        this.tileBatch = new ManagedTileBatch(renderer, texture);

        defineCharacterRegions();
    }

    /**
     * Define atlas regions for all characters in the font.
     */
    private function defineCharacterRegions():Void {
        var regionCount = 0;

        for (charCode in fontData.chars.keys()) {
            var fontChar = fontData.chars.get(charCode);

            var regionId = tileBatch.defineRegion(
                fontChar.x,
                fontChar.y,
                fontChar.width,
                fontChar.height
            );

            charCodeToRegion.set(charCode, regionId);
            regionCount++;
        }

        trace("BitmapFont: Defined " + regionCount + " character regions");
    }

    /**
     * Get the region ID for a character code.
     * Returns -1 if the character is not defined.
     */
    public function getRegionForChar(charCode:Int):Int {
        var regionId = charCodeToRegion.get(charCode);
        return regionId != null ? regionId : -1;
    }

    /**
     * Get character data for a character code.
     */
    public function getCharData(charCode:Int):loaders.FontData.FontChar {
        return fontData.chars.get(charCode);
    }

    public function markDirty():Void {
        tileBatch.markDirty();
    }

    public function addTile(x:Float, y:Float, width:Float, height:Float, regionId:Int):Int {
        return tileBatch.addTile(x, y, width, height, regionId);
    }

    public function removeTile(tileId:Int):Bool {
        return tileBatch.removeTile(tileId);
    }

    public function getTile(tileId:Int):Tile {
        return tileBatch.getTile(tileId);
    }

    public function clear():Void {
        tileBatch.clear();
    }

    public function getTileCount():Int {
        return tileBatch.getTileCount();
    }

    public function render(renderer:Renderer):Void {
        tileBatch.render(renderer);
    }

    private function get_atlasRegions():Map<Int, AtlasRegion> {
        return tileBatch.atlasRegions;
    }

    /**
     * Calculate the width of a text string using this font.
     */
    public function measureTextWidth(text:String):Float {
        var width:Float = 0;
        var currentLineWidth:Float = 0;

        for (i in 0...text.length) {
            var charCode = text.charCodeAt(i);

            if (charCode == 10) {
                if (currentLineWidth > width) {
                    width = currentLineWidth;
                }
                currentLineWidth = 0;
                continue;
            }

            var fontChar = fontData.chars.get(charCode);
            if (fontChar != null) {
                currentLineWidth += fontChar.xadvance;
            }
        }

        if (currentLineWidth > width) {
            width = currentLineWidth;
        }

        return width;
    }

    /**
     * Calculate the height of a text string using this font.
     */
    public function measureTextHeight(text:String):Float {
        var lines = 1;

        for (i in 0...text.length) {
            if (text.charCodeAt(i) == 10) {
                lines++;
            }
        }

        return lines * fontData.lineHeight;
    }
}