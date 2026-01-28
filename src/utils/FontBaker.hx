package utils;

import sys.io.File;
import sys.FileSystem;
import haxe.io.Bytes;
import haxe.Json;
import stb.STB_Truetype;
import cpp.Pointer;
import cpp.Native;
import cpp.NativeArray;
import cpp.UInt8;
import loaders.TGAExporter;
import data.TextureData;
import utils.BakedFontData;

/**
 * FontBaker - Generates pixel-perfect bitmap font atlases from TrueType fonts
 * 
 * Uses stb_truetype's Pack API optimized for crisp pixel art fonts.
 * Key techniques for pixel art:
 * - Exact pixel height scaling (1:1 pixel-to-texel ratio)
 * - No oversampling (prevents anti-aliasing blur)
 * - Binary threshold to ensure pure black/white pixels
 * - GL_NEAREST filtering (set in Renderer)
 */
class FontBaker {
    
    /**
     * Bake a TrueType font to bitmap atlas in memory
     * 
     * Optimized for pixel art fonts - renders at exact size without anti-aliasing.
     * Returns BakedFontData which can be used directly for rendering or exported to files.
     * 
     * @param ttfPath Path to .ttf font file (e.g., "res/fonts/nokiafc22.ttf")
     * @param fontName Font name for metadata
     * @param fontSize Font size in pixels (MUST match font's designed size for pixel art)
     * @param atlasWidth Atlas texture width (power of 2, e.g., 512)
     * @param atlasHeight Atlas texture height (power of 2, e.g., 512)
     * @param firstChar First character to bake (32 = space)
     * @param numChars Number of characters to bake (96 = ASCII printable)
     * @return BakedFontData with all font properties and texture data
     */
    public static function bakeFont(
        ttfPath:String,
        fontName:String,
        fontSize:Float = 16,
        atlasWidth:Int = 512,
        atlasHeight:Int = 512,
        firstChar:Int = 32,
        numChars:Int = 96
    ):BakedFontData {
        trace("FontBaker: Loading font from " + ttfPath);
        
        // Read font file
        if (!FileSystem.exists(ttfPath)) {
            trace("FontBaker: ERROR - Font file not found: " + ttfPath);
            throw "Font file not found: " + ttfPath;
        }
        
        var fontBytes = File.getBytes(ttfPath);
        trace("FontBaker: Read " + fontBytes.length + " bytes");
        
        // Get native pointer for font initialization
        var fontPtr:cpp.ConstPointer<cpp.UInt8> = untyped __cpp__("(const unsigned char*){0}->b->GetBase()",  fontBytes);
        
        // Initialize font info to get metrics
        var fontInfoBytes = haxe.io.Bytes.alloc(512); // Allocate space for FontInfo struct
        var fontInfoPtr:cpp.Pointer<stb.STB_Truetype.FontInfo> = untyped __cpp__("(stbtt_fontinfo*){0}->b->GetBase()", fontInfoBytes);
        
        var initResult = STB_Truetype.initFont(fontInfoPtr, fontPtr, 0);
        if (initResult == 0) {
            trace("FontBaker: ERROR - Failed to initialize font");
            throw "Failed to initialize font";
        }
        
        // Get font vertical metrics
        var ascent:Int = 0;
        var descent:Int = 0;
        var lineGap:Int = 0;
        STB_Truetype.getFontVMetrics(fontInfoPtr, untyped __cpp__("&{0}", ascent), untyped __cpp__("&{0}", descent), untyped __cpp__("&{0}", lineGap));
        
        // Calculate scale for EXACT pixel height (critical for pixel art!)
        // Use scaleForPixelHeight to match the font's designed size exactly
        var scale = STB_Truetype.scaleForPixelHeight(fontInfoPtr, fontSize);
        
        // Calculate pixel alignment metrics
        var unitsPerEM = ascent - descent;  // Total font units for height
        var scaledHeight = (ascent - descent) * scale;
        var scaledAscent = ascent * scale;
        var scaledDescent = descent * scale;
        
        // Check if metrics align to integer pixels (critical for pixel-perfect rendering)
        var heightIsInteger = Math.abs(scaledHeight - Math.round(scaledHeight)) < 0.0001;
        var ascentIsInteger = Math.abs(scaledAscent - Math.round(scaledAscent)) < 0.0001;
        
        trace("FontBaker: Font metrics (unscaled):");
        trace("  Ascent: " + ascent + " units");
        trace("  Descent: " + descent + " units");
        trace("  LineGap: " + lineGap + " units");
        trace("  Total height (UnitsPerEM): " + unitsPerEM + " units");
        trace("");
        trace("FontBaker: Scaling analysis:");
        trace("  Requested size: " + fontSize + "px");
        trace("  Scale factor: " + scale);
        trace("  Inverse scale (units per pixel): " + (1.0 / scale));
        trace("  Scaled height: " + scaledHeight + "px" + (heightIsInteger ? " ✓ EXACT" : " ⚠ SUB-PIXEL"));
        trace("  Scaled ascent: " + scaledAscent + "px" + (ascentIsInteger ? " ✓ EXACT" : " ⚠ SUB-PIXEL"));
        trace("  Scaled descent: " + scaledDescent + "px");
        trace("");
        trace("FontBaker: Pixel-perfect analysis:");
        trace("  For perfect alignment, " + unitsPerEM + " font units should map to integer pixels");
        trace("  At " + fontSize + "px: 1 pixel = " + (unitsPerEM / fontSize) + " font units");
        
        // Calculate ALL native/optimal sizes by finding divisors of unitsPerEM
        var optimalSizes = [];
        var minSize = 4;
        var maxSize = 128;
        
        // Find all divisors of unitsPerEM within reasonable size range
        for (testSize in minSize...maxSize + 1) {
            if (unitsPerEM % testSize == 0) {
                optimalSizes.push(testSize);
            }
        }
        
        if (optimalSizes.length > 0) {
            trace("  Native pixel-perfect sizes (divisors of " + unitsPerEM + "): " + optimalSizes.join(", ") + "px");
            trace("  Total: " + optimalSizes.length + " optimal sizes found");
        }
        trace("");
        
        // Allocate atlas bitmap (1 channel, 8bpp)
        var atlasBytes = haxe.io.Bytes.alloc(atlasWidth * atlasHeight);
        for (i in 0...atlasBytes.length) {
            atlasBytes.set(i, 0); // Clear to transparent
        }
        
        // Allocate pack context
        var packContextBytes = haxe.io.Bytes.alloc(1024); // Allocate space for pack context
        var packContext:cpp.Pointer<stb.STB_Truetype.PackContext> = untyped __cpp__("(stbtt_pack_context*){0}->b->GetBase()", packContextBytes);
        
        // Allocate character data array for PackedChar
        var charDataBytes = haxe.io.Bytes.alloc(numChars * 40); // PackedChar is ~36 bytes
        
        // Get native pointers
        var atlasPtr:cpp.Pointer<cpp.UInt8> = untyped __cpp__("(unsigned char*){0}->b->GetBase()", atlasBytes);
        var charPtr:cpp.Pointer<stb.STB_Truetype.PackedChar> = untyped __cpp__("(stbtt_packedchar*){0}->b->GetBase()", charDataBytes);
        
        // Initialize packing
        trace("FontBaker: Initializing pack context...");
        var packResult = STB_Truetype.packBegin(
            packContext,
            atlasPtr,
            atlasWidth,
            atlasHeight,
            0,  // stride (0 = tightly packed)
            1,  // padding between characters
            null // default allocator
        );
        
        if (packResult == 0) {
            trace("FontBaker: ERROR - Failed to initialize pack context");
            throw "Failed to initialize pack context";
        }
        
        // Set oversampling to 1x1 - NO oversampling for pixel art!
        // This prevents anti-aliasing blur
        trace("FontBaker: Setting oversampling: 1x1 (NO anti-aliasing for pixel art)");
        STB_Truetype.packSetOversampling(packContext, 1, 1);
        
        // Pack the font range
        trace("FontBaker: Packing font at " + fontSize + "px...");
        trace("  Atlas: " + atlasWidth + "x" + atlasHeight);
        trace("  Characters: " + firstChar + " to " + (firstChar + numChars - 1));
        
        var result = STB_Truetype.packFontRange(
            packContext,
            fontPtr,
            0,  // font index
            fontSize,
            firstChar,
            numChars,
            charPtr
        );
        
        if (result == 0) {
            trace("FontBaker: ERROR - Failed to pack font");
            STB_Truetype.packEnd(packContext);
            throw "Failed to pack font - atlas too small or font too large";
        }
        
        trace("FontBaker: Successfully packed font!");
        
        // Clean up pack context
        STB_Truetype.packEnd(packContext);
        
        // Convert Bytes to UInt8Array for processing
        var atlasPixels = new haxe.io.UInt8Array(atlasBytes.length);
        for (i in 0...atlasBytes.length) {
            atlasPixels[i] = atlasBytes.get(i);
        }
        
        // Apply binary threshold to ensure crisp pixel art edges
        // Convert grayscale to pure binary: >=128 = opaque (255), <128 = transparent (0)
        // This removes any residual anti-aliasing
        trace("FontBaker: Applying binary threshold for crisp pixel art edges");
        var threshold = 128;
        for (i in 0...atlasPixels.length) {
            atlasPixels[i] = atlasPixels[i] >= threshold ? 255 : 0;
        }
        
        // Calculate font metrics for baseline
        var scaledAscent = Std.int(ascent * scale);
        var scaledDescent = Std.int(Math.abs(descent) * scale);
        var lineHeight = Std.int((ascent - descent + lineGap) * scale);
        var base = scaledAscent; // Baseline is at ascent from top
        
        trace("FontBaker: Font metrics - lineHeight=" + lineHeight + ", base=" + base + " (ascent=" + scaledAscent + ", descent=" + scaledDescent + ")");
        
        // Build JSON metadata (compatible with FontLoader format)
        var atlasFileName = fontName + ".tga";
        var chars = [];
        
        trace("FontBaker: Extracting character data...");
        
        for (i in 0...numChars) {
            var charCode = firstChar + i;
            var packedChar = charPtr[i];
            
            // PackedChar coordinates are already in atlas space
            var x = packedChar.x0;
            var y = packedChar.y0;
            var width = packedChar.x1 - packedChar.x0;
            var height = packedChar.y1 - packedChar.y0;
            
            // Use integer offsets for pixel-perfect positioning
            // For PackedChar: xoff/yoff are rendering offsets (baseline-relative)
            // Convert yoff from baseline-relative to top-relative by adding scaledAscent
            var xoffset = Math.round(packedChar.xoff);
            var yoffset = Math.round(packedChar.yoff + scaledAscent);
            var xadvance = Math.round(packedChar.xadvance);
            
            // Debug printable characters
            if (charCode >= 33 && charCode <= 126) {
                var chr = String.fromCharCode(charCode);
                trace("  [" + charCode + "] '" + chr + "': atlas(" + x + "," + y + " " + width + "x" + height + 
                      ") offset(" + xoffset + "," + yoffset + ") advance=" + xadvance);
            }
            
            chars.push({
                "_id": Std.string(charCode),
                "_x": Std.string(x),
                "_y": Std.string(y),
                "_width": Std.string(width),
                "_height": Std.string(height),
                "_xoffset": Std.string(Std.int(xoffset)),
                "_yoffset": Std.string(Std.int(yoffset)),
                "_xadvance": Std.string(Std.int(xadvance)),
                "_page": "0",
                "_chnl": "15"
            });
        }
        
        // Store metrics for export
        var metricsData = {
            "_ascent": Std.string(ascent),
            "_descent": Std.string(descent),
            "_lineGap": Std.string(lineGap),
            "_unitsPerEM": Std.string(unitsPerEM),
            "_scale": Std.string(scale),
            "_scaledAscent": Std.string(scaledAscent),
            "_scaledDescent": Std.string(scaledDescent)
        };
        
        // Convert atlas to RGBA for texture
        var rgbaPixels = new haxe.io.UInt8Array(atlasWidth * atlasHeight * 4);
        for (i in 0...atlasPixels.length) {
            var alpha = atlasPixels[i];
            var idx = i * 4;
            rgbaPixels[idx + 0] = 255;  // R
            rgbaPixels[idx + 1] = 255;  // G
            rgbaPixels[idx + 2] = 255;  // B
            rgbaPixels[idx + 3] = alpha; // A (use font alpha as alpha channel)
        }
        
        // Create texture data
        var textureData = new TextureData(rgbaPixels, 4, atlasWidth, atlasHeight, true);
        
        trace("FontBaker: Font baking complete!");
        trace("  Font data ready in memory - call exportToFiles() to save to disk");
        
        // Return baked font data
        return new BakedFontData(
            fontName,
            Std.int(fontSize),
            atlasWidth,
            atlasHeight,
            lineHeight,
            base,
            textureData,
            chars,
            metricsData
        );
    }
}
