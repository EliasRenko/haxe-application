package utils;

import haxe.io.Bytes;
import stb.STB_Truetype;
import cpp.Pointer;
import cpp.UInt8;
import data.TextureData;
import utils.BakedFontData;

/**
 * FontBaker - Generates pixel-perfect bitmap font atlases from TrueType fonts.
 *
 * Two entry points:
 *   bakeFontFromBytes()  — single font, single atlas (unchanged behaviour)
 *   bakeMultiple()       — multiple fonts/sizes packed into one shared atlas
 *
 * Both return BakedFontData.  The output JSON per face is identical to the
 * existing BMFont format, so FontLoader.load() keeps working without changes.
 */
class FontBaker {

    // ── Public API ────────────────────────────────────────────────────────────

    /**
     * Bake one TrueType font into a bitmap atlas.
     * Identical behaviour to the old implementation — call sites unchanged.
     */
    public static function bakeFontFromBytes(
        fontBytes:Bytes,
        fontName:String,
        fontSize:Float  = 16,
        atlasWidth:Int  = 512,
        atlasHeight:Int = 512,
        firstChar:Int   = 32,
        numChars:Int    = 96
    ):BakedFontData {
        return bakeMultiple(
            [{ bytes: fontBytes, name: fontName, size: fontSize,
               firstChar: firstChar, numChars: numChars }],
            atlasWidth, atlasHeight
        );
    }

    /**
     * Pack multiple fonts/sizes into one shared atlas.
     *
     * @param entries   Array of font descriptors.  Each needs:
     *                    bytes      — raw TTF bytes
     *                    name       — identifier used in the exported JSON
     *                    size       — font size in pixels
     *                    firstChar  — first codepoint to bake (default 32)
     *                    numChars   — number of chars to bake  (default 96)
     * @param atlasWidth   Width of the shared atlas (power-of-two)
     * @param atlasHeight  Height of the shared atlas (power-of-two)
     */
    public static function bakeMultiple(
        entries:Array<{ bytes:Bytes, name:String, size:Float,
                         ?firstChar:Null<Int>, ?numChars:Null<Int> }>,
        atlasWidth:Int  = 512,
        atlasHeight:Int = 512
    ):BakedFontData {
        if (entries.length == 0) throw "FontBaker: no entries provided";

        trace("FontBaker: baking " + entries.length + " font(s) into a "
              + atlasWidth + "x" + atlasHeight + " atlas");

        // ── Allocate shared atlas ─────────────────────────────────────────────
        var atlasBytes = Bytes.alloc(atlasWidth * atlasHeight);
        for (i in 0...atlasBytes.length) atlasBytes.set(i, 0);

        var packContextBytes = Bytes.alloc(1024);
        var packContext:Pointer<PackContext> =
            untyped __cpp__("(stbtt_pack_context*){0}->b->GetBase()", packContextBytes);

        var atlasPtr:Pointer<UInt8> =
            untyped __cpp__("(unsigned char*){0}->b->GetBase()", atlasBytes);

        var packResult = STB_Truetype.packBegin(
            packContext, atlasPtr, atlasWidth, atlasHeight, 0, 1, null);
        if (packResult == 0) throw "FontBaker: failed to init pack context";

        STB_Truetype.packSetOversampling(packContext, 1, 1);

        // ── Pack every entry ──────────────────────────────────────────────────
        // We keep per-entry chardata buffers alive until after packEnd.
        var entryBuffers:Array<{
            charDataBytes:Bytes,
            firstChar:Int,
            numChars:Int
        }> = [];

        for (entry in entries) {
            var fc = entry.firstChar != null ? entry.firstChar : 32;
            var nc = entry.numChars  != null ? entry.numChars  : 96;

            var entryBytes:Bytes = entry.bytes;
            var fontPtr:cpp.ConstPointer<UInt8> =
                untyped __cpp__("(const unsigned char*){0}->b->GetBase()", entryBytes);

            var charDataBytes = Bytes.alloc(nc * 40);
            var charPtr:Pointer<PackedChar> =
                untyped __cpp__("(stbtt_packedchar*){0}->b->GetBase()", charDataBytes);

            trace('FontBaker: packing "${entry.name}" @ ${entry.size}px');
            var r = STB_Truetype.packFontRange(
                packContext, fontPtr, 0, entry.size, fc, nc, charPtr);
            if (r == 0) {
                STB_Truetype.packEnd(packContext);
                throw 'FontBaker: failed to pack "${entry.name}" @ ${entry.size}px — atlas too small?';
            }

            entryBuffers.push({ charDataBytes: charDataBytes,
                                 firstChar: fc, numChars: nc });
        }

        STB_Truetype.packEnd(packContext);

        // ── Binary threshold ──────────────────────────────────────────────────
        var atlasPixels = new haxe.io.UInt8Array(atlasBytes.length);
        for (i in 0...atlasBytes.length) atlasPixels[i] = atlasBytes.get(i);
        for (i in 0...atlasPixels.length)
            atlasPixels[i] = atlasPixels[i] >= 128 ? 255 : 0;

        // ── Convert to RGBA ───────────────────────────────────────────────────
        var rgbaPixels = new haxe.io.UInt8Array(atlasWidth * atlasHeight * 4);
        for (i in 0...atlasPixels.length) {
            var a = atlasPixels[i];
            var idx = i * 4;
            rgbaPixels[idx + 0] = 255;
            rgbaPixels[idx + 1] = 255;
            rgbaPixels[idx + 2] = 255;
            rgbaPixels[idx + 3] = a;
        }
        var textureData = new TextureData(rgbaPixels, 4, atlasWidth, atlasHeight, true);

        // ── Build one BakedFace per entry ─────────────────────────────────────
        var faces:Array<BakedFace> = [];

        for (ei in 0...entries.length) {
            var entry  = entries[ei];
            var buf    = entryBuffers[ei];
            var entryBytes:Bytes = entry.bytes;
            var bufCharData:Bytes = buf.charDataBytes;
            var face   = _buildFace(entryBytes, entry.name, entry.size,
                                    buf.firstChar, buf.numChars, bufCharData);
            faces.push(face);
        }

        trace("FontBaker: multi-bake complete (" + faces.length + " face(s))");
        return new BakedFontData(atlasWidth, atlasHeight, textureData, faces);
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    /**
     * Extract per-face metadata from an already-packed charPtr.
     * Does NOT touch the atlas pixels — only reads font metrics + chardata.
     */
    private static function _buildFace(
        fontBytes:Bytes,
        fontName:String,
        fontSize:Float,
        firstChar:Int,
        numChars:Int,
        charDataBytes:Bytes
    ):BakedFace {
        var charPtr:Pointer<PackedChar> =
            untyped __cpp__("(stbtt_packedchar*){0}->b->GetBase()", charDataBytes);
        var fontPtr:cpp.ConstPointer<UInt8> =
            untyped __cpp__("(const unsigned char*){0}->b->GetBase()", fontBytes);

        var fontInfoBytes = Bytes.alloc(512);
        var fontInfoPtr:Pointer<FontInfo> =
            untyped __cpp__("(stbtt_fontinfo*){0}->b->GetBase()", fontInfoBytes);

        if (STB_Truetype.initFont(fontInfoPtr, fontPtr, 0) == 0)
            throw 'FontBaker: failed to init font "${fontName}"';

        var ascent:Int = 0; var descent:Int = 0; var lineGap:Int = 0;
        STB_Truetype.getFontVMetrics(fontInfoPtr,
            untyped __cpp__("&{0}", ascent),
            untyped __cpp__("&{0}", descent),
            untyped __cpp__("&{0}", lineGap));

        var scale       = STB_Truetype.scaleForPixelHeight(fontInfoPtr, fontSize);
        var scaledAscent  = Std.int(ascent * scale);
        var scaledDescent = Std.int(Math.abs(descent) * scale);
        var lineHeight  = Std.int((ascent - descent + lineGap) * scale);
        var base        = scaledAscent;
        var unitsPerEM  = ascent - descent;

        var chars = [];
        for (i in 0...numChars) {
            var charCode  = firstChar + i;
            var pc        = charPtr[i];
            var xoffset   = Math.round(pc.xoff);
            var yoffset   = Math.round(pc.yoff + scaledAscent);
            var xadvance  = Math.round(pc.xadvance);
            chars.push({
                "_id":       Std.string(charCode),
                "_x":        Std.string(pc.x0),
                "_y":        Std.string(pc.y0),
                "_width":    Std.string(pc.x1 - pc.x0),
                "_height":   Std.string(pc.y1 - pc.y0),
                "_xoffset":  Std.string(xoffset),
                "_yoffset":  Std.string(yoffset),
                "_xadvance": Std.string(xadvance),
                "_page":     "0",
                "_chnl":     "15"
            });
        }

        var metricsData = {
            "_ascent":        Std.string(ascent),
            "_descent":       Std.string(descent),
            "_lineGap":       Std.string(lineGap),
            "_unitsPerEM":    Std.string(unitsPerEM),
            "_scale":         Std.string(scale),
            "_scaledAscent":  Std.string(scaledAscent),
            "_scaledDescent": Std.string(scaledDescent)
        };

        return {
            fontName:   fontName,
            fontSize:   Std.int(fontSize),
            lineHeight: lineHeight,
            base:       base,
            chars:      chars,
            metrics:    metricsData
        };
    }
}
