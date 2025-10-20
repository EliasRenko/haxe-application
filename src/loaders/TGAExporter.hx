package loaders;

import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import data.TextureData;

class TGAExporter {
    
    /**
     * Save a TextureData to a TGA file
     */
    public static function saveToTGA(tex:TextureData, filename:String):Void {
        var width = tex.width;
        var height = tex.height;
        var bpp = tex.bytesPerPixel * 8;
        var hasAlpha = tex.bytesPerPixel == 4;

        var buf = new BytesBuffer();

        // --- TGA Header (18 bytes) ---
        buf.addByte(0); // ID length
        buf.addByte(0); // Color map type
        buf.addByte(2); // Image type: uncompressed true-color

        // Color map spec (5 bytes)
        buf.addByte(0); buf.addByte(0); // Color map origin
        buf.addByte(0); buf.addByte(0); // Color map length
        buf.addByte(0);                  // Color map depth

        // Image spec (10 bytes)
        buf.addByte(0); buf.addByte(0); // X origin
        buf.addByte(0); buf.addByte(0); // Y origin
        buf.addByte(width & 0xFF); buf.addByte(width >> 8);
        buf.addByte(height & 0xFF); buf.addByte(height >> 8);
        buf.addByte(bpp); // Pixel depth
        buf.addByte(0x20); // Image descriptor: top-left origin

        // --- Pixel Data (BGR or BGRA order) ---
        var src = tex.bytes;
        var bppBytes = tex.bytesPerPixel;
        
        for (y in 0...height) {
            for (x in 0...width) {
                var i = (y * width + x) * bppBytes;
                var r = src[i];
                var g = src[i + 1];
                var b = src[i + 2];
                buf.addByte(b);
                buf.addByte(g);
                buf.addByte(r);
                if (hasAlpha) buf.addByte(src[i + 3]);
            }
        }

        // --- Save to file ---
        sys.io.File.saveBytes(filename, buf.getBytes());
    }
}
