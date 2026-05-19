package utils;

import haxe.Json;
import haxe.io.UInt8Array;
import data.TextureData;
import loaders.TGALoader;
import utils.BinPacker;

/**
 * An image entry to pack into the atlas.
 * name  — identifier used in the exported JSON (defaults to the filename without extension)
 * path  — absolute or relative path to a TGA image file
 */
typedef PackEntry = {
    var name:String;
    var path:String;
}

/**
 * Describes the position and size of one image inside the packed atlas.
 */
typedef PackedRegion = {
    var name:String;
    var x:Int;
    var y:Int;
    var width:Int;
    var height:Int;
}

/**
 * Result returned by TexturePacker.pack().
 */
typedef PackResult = {
    var atlasData:TextureData;
    var atlasWidth:Int;
    var atlasHeight:Int;
    var regions:Array<PackedRegion>;
    /** Names of entries that could not be placed (file missing or atlas full). */
    var failed:Array<String>;
}

/**
 * TexturePacker — packs multiple TGA images into a single RGBA atlas using
 * the Guillotine bin-packing algorithm (BestShortSideFit).
 *
 * Usage:
 *   var result = TexturePacker.pack(entries, 512, 512);
 *   var json   = TexturePacker.toJson(result, "my_atlas.tga");
 */
class TexturePacker {

    // ── Public API ────────────────────────────────────────────────────────────

    /**
     * Pack all entries into an atlasWidth × atlasHeight RGBA atlas.
     *
     * @param entries     List of images to pack.
     * @param atlasWidth  Width  of the output atlas (power-of-two recommended).
     * @param atlasHeight Height of the output atlas (power-of-two recommended).
     * @return PackResult with the atlas TextureData, packed regions, and any
     *         entries that failed to fit.
     */
    public static function pack(
        entries:Array<PackEntry>,
        atlasWidth:Int,
        atlasHeight:Int
    ):PackResult {
        var images:Array<{ td:TextureData, entry:PackEntry }> = [];
        var failed:Array<String> = [];

        #if sys
        for (e in entries) {
            if (!sys.FileSystem.exists(e.path)) {
                failed.push(e.name + " (file not found)");
                continue;
            }
            var bytes = sys.io.File.getBytes(e.path);
            var td    = TGALoader.loadFromBytes(bytes, e.path);
            images.push({ td: td, entry: e });
        }
        #end

        // Allocate transparent-black RGBA atlas buffer
        var atlasData = new UInt8Array(atlasWidth * atlasHeight * 4);

        var packer = new BinPacker(atlasWidth, atlasHeight, false);
        var regions:Array<PackedRegion> = [];

        for (img in images) {
            var td   = img.td;
            var rect = packer.insert(
                td.width, td.height, true,
                GuillotineFreeRectChoiceHeuristic.BestShortSideFit,
                GuillotineSplitHeuristic.ShorterLeftoverAxis
            );

            if (rect == null) {
                failed.push(img.entry.name + " (atlas full)");
                continue;
            }

            var rx = Std.int(rect.x);
            var ry = Std.int(rect.y);

            _blit(td, atlasData, atlasWidth, rx, ry);

            regions.push({
                name:   img.entry.name,
                x:      rx,
                y:      ry,
                width:  td.width,
                height: td.height
            });
        }

        var atlasTd = new TextureData(atlasData, 4, atlasWidth, atlasHeight, true);

        return {
            atlasData:   atlasTd,
            atlasWidth:  atlasWidth,
            atlasHeight: atlasHeight,
            regions:     regions,
            failed:      failed
        };
    }

    /**
     * Serialise a PackResult to a JSON string.
     *
     * The JSON format is:
     * {
     *   "atlas":   "name.tga",
     *   "width":   512,
     *   "height":  512,
     *   "regions": [
     *     { "name": "button", "x": 0, "y": 0, "width": 32, "height": 32 },
     *     ...
     *   ]
     * }
     *
     * @param result        The pack result to serialise.
     * @param atlasFileName Filename (with extension) of the exported TGA, stored
     *                      in the "atlas" field so consumers know which file to load.
     */
    public static function toJson(result:PackResult, atlasFileName:String):String {
        var obj:Dynamic = {
            atlas:   atlasFileName,
            width:   result.atlasWidth,
            height:  result.atlasHeight,
            regions: result.regions
        };
        return Json.stringify(obj, null, "  ");
    }

    // ── Private helpers ───────────────────────────────────────────────────────

    /**
     * Blit src pixels (RGB or RGBA) into a flat RGBA destination buffer.
     *
     * @param src      Source TextureData (3 or 4 bytes-per-pixel).
     * @param dstData  Destination RGBA UInt8Array (4 bytes-per-pixel).
     * @param dstWidth Width of the destination atlas in pixels.
     * @param dstX     X offset into the destination atlas.
     * @param dstY     Y offset into the destination atlas.
     */
    private static function _blit(
        src:TextureData,
        dstData:UInt8Array,
        dstWidth:Int,
        dstX:Int,
        dstY:Int
    ):Void {
        var srcBpp   = src.bytesPerPixel;
        var srcBytes = src.bytes;
        var hasAlpha = srcBpp == 4;

        for (y in 0...src.height) {
            for (x in 0...src.width) {
                var si = (y * src.width + x) * srcBpp;
                var di = ((dstY + y) * dstWidth + (dstX + x)) * 4;
                dstData[di]     = srcBytes[si];
                dstData[di + 1] = srcBytes[si + 1];
                dstData[di + 2] = srcBytes[si + 2];
                dstData[di + 3] = hasAlpha ? srcBytes[si + 3] : 255;
            }
        }
    }
}
