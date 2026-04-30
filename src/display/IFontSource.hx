package display;

import display.Tile;
import loaders.FontData;
import loaders.FontData.FontChar;

/**
 * IFontSource — common interface consumed by Text for glyph tile management.
 *
 * Implemented by:
 *   - BitmapFont  (standalone rendering via its own ManagedTileBatch)
 *   - UIFont      (private class inside Canvas, proxies into the unified UIBatch)
 *
 * Text only depends on this interface, so it works transparently in both
 * contexts without knowing which backend is in use.
 */
interface IFontSource {

    var fontData:FontData;

    function markDirty():Void;
    function getRegionForChar(charCode:Int):Int;
    function getCharData(charCode:Int):FontChar;

    function addTile(x:Float, y:Float, width:Float, height:Float, regionId:Int):Int;
    function removeTile(tileId:Int):Bool;
    function getTile(tileId:Int):Tile;

    function measureTextWidth(text:String):Float;
    function measureTextHeight(text:String):Float;
}
