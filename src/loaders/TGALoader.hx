package loaders;

import haxe.io.UInt8Array;
import haxe.io.BytesInput;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import data.TextureData;


class TGALoader {
	// TGA Header structure (18 bytes)
	private static inline var TGA_HEADER_SIZE = 18;

	// Image type constants
	private static inline var TGA_NO_IMAGE = 0;
	private static inline var TGA_UNCOMPRESSED_COLOR_MAPPED = 1;
	private static inline var TGA_UNCOMPRESSED_RGB = 2;
	private static inline var TGA_UNCOMPRESSED_GRAYSCALE = 3;
	private static inline var TGA_RLE_COLOR_MAPPED = 9;
	private static inline var TGA_RLE_RGB = 10;
	private static inline var TGA_RLE_GRAYSCALE = 11;

	/**
	 * Decompresses RLE-encoded TGA data
	 */
	private static function decompressRLE(input:BytesInput, width:Int, height:Int, bytesPerPixel:Int):Bytes {
		var expectedSize = width * height * bytesPerPixel;
		var output = new UInt8Array(expectedSize);
		var outIndex = 0;

		while (outIndex < expectedSize) {
			var header = input.readByte();
			var isRLE = (header & 0x80) != 0;
			var count = (header & 0x7F) + 1;

			if (isRLE) {
				// RLE packet - repeat next pixel 'count' times
				var pixel = new UInt8Array(bytesPerPixel);
				for (i in 0...bytesPerPixel) {
					pixel[i] = input.readByte();
				}

				for (i in 0...count) {
					for (j in 0...bytesPerPixel) {
						if (outIndex < expectedSize) {
							output[outIndex++] = pixel[j];
						}
					}
				}
			} else {
				// Raw packet - copy next 'count' pixels directly
				for (i in 0...count) {
					for (j in 0...bytesPerPixel) {
						if (outIndex < expectedSize) {
							output[outIndex++] = input.readByte();
						}
					}
				}
			}
		}

		// Convert UInt8Array to Bytes properly
		var result = Bytes.alloc(expectedSize);
		for (i in 0...expectedSize) {
			result.set(i, output[i]);
		}

		return result;
	}

	public static function loadFromBytes(bytes:Bytes):TextureData {
		if (bytes.length < TGA_HEADER_SIZE) {
			throw "Invalid TGA file: too small";
		}

		var input = new BytesInput(bytes);

		// Read TGA header
		var idLength = input.readByte(); // 0: ID field length
		var colorMapType = input.readByte(); // 1: Color map type
		var imageType = input.readByte(); // 2: Image type

		// Color map specification (5 bytes)
		var colorMapStart = input.readUInt16(); // 3-4: Color map start
		var colorMapLength = input.readUInt16(); // 5-6: Color map length
		var colorMapDepth = input.readByte(); // 7: Color map depth

		// Image specification (10 bytes)
		var xOrigin = input.readUInt16(); // 8-9: X origin
		var yOrigin = input.readUInt16(); // 10-11: Y origin
		var width = input.readUInt16(); // 12-13: Width
		var height = input.readUInt16(); // 14-15: Height
		var pixelDepth = input.readByte(); // 16: Pixel depth
		var imageDescriptor = input.readByte(); // 17: Image descriptor

		// Extract origin information from image descriptor
		var originTop = (imageDescriptor & 0x20) != 0; // Bit 5: 0=bottom origin, 1=top origin
		var originLeft = (imageDescriptor & 0x10) == 0; // Bit 4: 0=left origin, 1=right origin

		// Skip ID field if present
		if (idLength > 0) {
			input.read(idLength);
		}

		trace("TGA Header - Type: " + imageType + ", PixelDepth: " + pixelDepth + ", Width: " + width + ", Height: " + height);
		trace("TGA Origin - Top: " + originTop + ", Left: " + originLeft);

		// Support multiple TGA formats
		var isColorMapped = (imageType == TGA_UNCOMPRESSED_COLOR_MAPPED || imageType == TGA_RLE_COLOR_MAPPED);
		var isGrayscale = (imageType == TGA_UNCOMPRESSED_GRAYSCALE || imageType == TGA_RLE_GRAYSCALE);
		var isRGB = (imageType == TGA_UNCOMPRESSED_RGB || imageType == TGA_RLE_RGB);
		var isRLE = (imageType == TGA_RLE_COLOR_MAPPED || imageType == TGA_RLE_RGB || imageType == TGA_RLE_GRAYSCALE);

		if (!isColorMapped && !isGrayscale && !isRGB) {
			throw "Unsupported TGA format: type " + imageType;
		}

		// Handle color map for indexed images
		var colorMap:UInt8Array = null;
		if (isColorMapped && colorMapType == 1) {
			var colorMapSize = colorMapLength * Math.floor(colorMapDepth / 8);
			var colorMapData = input.read(colorMapSize);
			colorMap = new UInt8Array(colorMapSize);
			for (i in 0...colorMapSize) {
				colorMap[i] = colorMapData.get(i);
			}
			trace("TGA: Loaded color map with " + colorMapLength + " entries, " + colorMapDepth + " bits each");
		}

		// Determine output format - always convert to standard formats
		var outputBytesPerPixel:Int;
		if (isGrayscale) {
			outputBytesPerPixel = 1; // Always output grayscale as 1 BPP
		} else if (isColorMapped) {
			// Color mapped images are converted to RGB or RGBA
			outputBytesPerPixel = (colorMapDepth >= 32) ? 4 : 3;
		} else {
			// RGB images
			if (pixelDepth <= 16) {
				outputBytesPerPixel = 3; // 15/16-bit RGB -> 24-bit RGB
			} else if (pixelDepth == 24) {
				outputBytesPerPixel = 3; // 24-bit RGB
			} else {
				outputBytesPerPixel = 4; // 32-bit RGBA
			}
		}

		// Calculate input bytes per pixel (what's stored in file)
		var inputBytesPerPixel = Math.floor(pixelDepth / 8);
		if (inputBytesPerPixel < 1) {
			inputBytesPerPixel = 1; // Handle sub-byte formats (like 1-bit)
		}

		// Special handling for 1-bit monochrome (common in bitmap fonts)
		var is1Bit = (pixelDepth == 1);
		if (is1Bit) {
			inputBytesPerPixel = Math.ceil(width / 8); // 1 bit per pixel, packed into bytes
		}

		// Calculate expected data size based on input format
		var expectedDataSize:Int;
		if (is1Bit) {
			expectedDataSize = Math.ceil(width * height / 8); // 1 bit per pixel, packed
		} else {
			expectedDataSize = width * height * inputBytesPerPixel;
		}

		// Read raw pixel data (handle RLE compression if present)
		var rawData:Bytes;
		if (isRLE) {
			trace("TGA: Decompressing RLE data...");
			if (is1Bit) {
				// For 1-bit RLE, we need special handling
				rawData = decompressRLE(input, width, height, 1);
			} else {
				rawData = decompressRLE(input, width, height, inputBytesPerPixel);
			}
		} else {
			var remainingBytes = bytes.length - input.position;
			if (remainingBytes < expectedDataSize) {
				throw "Invalid TGA file: insufficient image data (expected " + expectedDataSize + ", got " + remainingBytes + ")";
			}
			rawData = input.read(expectedDataSize);
		}

		// Create output pixel data array
		var outputDataSize = width * height * outputBytesPerPixel;
		var pixelData = new UInt8Array(outputDataSize);

		// Convert pixel data based on format
		// No Y-flipping - import texture exactly as stored in TGA file

		for (i in 0...(width * height)) {
			// Use direct linear mapping without Y-flipping
			var dstOffset = i * outputBytesPerPixel;

			if (is1Bit) {
				// 1-bit monochrome - unpack bits
				var byteIndex = Math.floor(i / 8);
				var bitIndex = i % 8;
				var byte = rawData.get(byteIndex);
				var bit = (byte >> (7 - bitIndex)) & 1; // MSB first
				pixelData[dstOffset] = bit * 255; // Convert 0/1 to 0/255
			} else if (isColorMapped) {
				// Color-mapped image - look up color in palette
				var srcOffset = i * inputBytesPerPixel;
				var index = rawData.get(srcOffset);
				if (colorMap != null && index < colorMapLength) {
					var palOffset = index * Math.floor(colorMapDepth / 8);
					if (outputBytesPerPixel >= 3) {
						// BGR -> RGB conversion for color map
						pixelData[dstOffset + 0] = colorMap[palOffset + 2]; // R
						pixelData[dstOffset + 1] = colorMap[palOffset + 1]; // G
						pixelData[dstOffset + 2] = colorMap[palOffset + 0]; // B
						if (outputBytesPerPixel == 4) {
							pixelData[dstOffset + 3] = (colorMapDepth >= 32) ? colorMap[palOffset + 3] : 255; // A
						}
					}
				} else {
					// Invalid index - fill with black
					for (j in 0...outputBytesPerPixel) {
						pixelData[dstOffset + j] = 0;
					}
				}
			} else if (isGrayscale) {
				// Grayscale image - direct copy or convert
				var srcOffset = i * inputBytesPerPixel;
				if (pixelDepth == 8) {
					pixelData[dstOffset] = rawData.get(srcOffset);
				} else if (pixelDepth == 16) {
					// 16-bit grayscale with alpha - take the intensity
					pixelData[dstOffset] = rawData.get(srcOffset);
				} else {
					// Handle other bit depths by scaling
					var value = rawData.get(srcOffset);
					pixelData[dstOffset] = value;
				}
			} else {
				// RGB image
				var srcOffset = i * inputBytesPerPixel;
				if (pixelDepth == 15 || pixelDepth == 16) {
					// 15/16-bit RGB - packed format
					var pixel = rawData.get(srcOffset) | (rawData.get(srcOffset + 1) << 8);
					if (pixelDepth == 15) {
						// 5-5-5 RGB
						pixelData[dstOffset + 0] = ((pixel >> 10) & 0x1F) << 3; // R
						pixelData[dstOffset + 1] = ((pixel >> 5) & 0x1F) << 3; // G
						pixelData[dstOffset + 2] = (pixel & 0x1F) << 3; // B
					} else {
						// 5-6-5 RGB
						pixelData[dstOffset + 0] = ((pixel >> 11) & 0x1F) << 3; // R
						pixelData[dstOffset + 1] = ((pixel >> 5) & 0x3F) << 2; // G
						pixelData[dstOffset + 2] = (pixel & 0x1F) << 3; // B
					}
				} else if (pixelDepth == 24) {
					// 24-bit RGB - BGR -> RGB conversion
					pixelData[dstOffset + 0] = rawData.get(srcOffset + 2); // R
					pixelData[dstOffset + 1] = rawData.get(srcOffset + 1); // G
					pixelData[dstOffset + 2] = rawData.get(srcOffset + 0); // B
				} else if (pixelDepth == 32) {
					// 32-bit RGBA - BGRA -> RGBA conversion
					pixelData[dstOffset + 0] = rawData.get(srcOffset + 2); // R
					pixelData[dstOffset + 1] = rawData.get(srcOffset + 1); // G
					pixelData[dstOffset + 2] = rawData.get(srcOffset + 0); // B
					pixelData[dstOffset + 3] = rawData.get(srcOffset + 3); // A
				}
			}
		}

		// Check if image has alpha channel
		var hasAlpha = (outputBytesPerPixel == 4) || (outputBytesPerPixel == 2);

		// Debug: Sample a few pixel values to verify conversion
		if (isGrayscale && outputDataSize > 100) {
			var sampleValues = [];
			for (i in 0...10) {
				var index = Math.floor(i * outputDataSize / 10);
				sampleValues.push(pixelData[index]);
			}
			trace("TGA Debug: First 10 sample pixel values: " + sampleValues);
		}

		trace("TGA converted: " + width + "x" + height + ", " + pixelDepth + " -> " + (outputBytesPerPixel * 8) + " bits, " + outputBytesPerPixel
			+ " BPP output");

		return new TextureData(pixelData, outputBytesPerPixel, width, height, hasAlpha);
	}

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

        buf.addByte(0); buf.addByte(0); // Color map origin
        buf.addByte(0); buf.addByte(0); // Color map length
        buf.addByte(0);                  // Color map depth

        buf.addByte(0); buf.addByte(0); // X origin
        buf.addByte(0); buf.addByte(0); // Y origin
        buf.addByte(width & 0xFF); buf.addByte(width >> 8);
        buf.addByte(height & 0xFF); buf.addByte(height >> 8);
        buf.addByte(bpp); // Pixel depth
        buf.addByte(0x20); // Image descriptor: top-left origin

        // --- Pixel Data ---
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
