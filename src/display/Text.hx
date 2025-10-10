package display;

import display.TilemapFast;
import haxe.Json;
import ProgramInfo;
import data.TextureData;
import Renderer;

/**
 * Simple bitmap font text renderer using TilemapFast
 * Renders text using a font atlas and character definitions from JSON
 */
class Text extends TilemapFast {
    
    // Text properties
    public var text:String = "";
    public var fontSize:Float = 1.0;  // Scale factor for font size
    public var color:Array<Float> = [1.0, 1.0, 1.0, 1.0];  // RGBA color (default white)
    
    // Font data
    private var fontData:BitmapFont = null;
    private var characterMap:Map<Int, CharData> = new Map();
    
    // Layout properties
    public var letterSpacing:Float = 0.0;  // Extra space between characters
    public var lineSpacing:Float = 0.0;    // Extra space between lines
    
    // Resource reference for loading
    private var __resources:Resources = null;
    private var __renderer:Renderer = null;
    
    /**
     * Create a new Text display object
     * @param programInfo Shader program for rendering
     * @param resources Resources instance for loading fonts
     * @param renderer Renderer instance for texture uploading
     * @param fontName Name of the font (e.g. "nokiafc22")
     * @param text Initial text to display
     * @param fontSize Scale factor for the font
     */
    public function new(programInfo:ProgramInfo, resources:Resources, renderer:Renderer, fontName:String = "nokiafc22", text:String = "", fontSize:Float = 1.0) {
        // Initialize with a minimal size - will be resized when text is set
        super(programInfo, 1, 1, 8);  // 1x1 grid, 8px tile size initially
        
        this.__resources = resources;
        this.__renderer = renderer;
        this.text = text;
        this.fontSize = fontSize;
        
        loadFont(fontName);
        updateText();
    }
    
    /**
     * Load bitmap font data from JSON
     */
    private function loadFont(fontName:String):Void {
        trace("Text: Loading font '" + fontName + "'...");
        
        // Load font texture
        var fontTexture = __resources.getTexture("textures/" + fontName + ".tga");
        if (fontTexture == null) {
            trace("Error: Font texture not found: textures/" + fontName + ".tga");
            return;
        }
        
        trace("Text: Found font texture data - Size: " + fontTexture.width + "x" + fontTexture.height + ", BPP: " + fontTexture.bytesPerPixel);
        
        // Load font data from JSON
        var jsonPath = "textures/" + fontName + ".json";
        var jsonContent = __resources.getText(jsonPath);
        if (jsonContent == null) {
            trace("Error: Font JSON not found: " + jsonPath);
            // Fall back to basic font
            createBasicFont(fontTexture);
            return;
        }
        
        trace("Text: Found font JSON data, parsing...");
        
        // Parse the JSON font data
        try {
            var fontData:BitmapFont = Json.parse(jsonContent);
            createFontFromJson(fontTexture, fontData);
        } catch (e:Dynamic) {
            trace("Error: Failed to parse font JSON: " + e);
            // Fall back to basic font
            createBasicFont(fontTexture);
        }
        
        trace("Text: Font '" + fontName + "' loaded successfully");
    }
    
    /**
     * Create font from parsed JSON data
     */
    private function createFontFromJson(fontTextureData:TextureData, fontData:BitmapFont):Void {
        trace("Text: Creating font from JSON data...");
        
        // Upload texture to GPU and get Texture object
        var fontTexture = __renderer.uploadTexture(fontTextureData);
        if (fontTexture == null) {
            trace("Error: Failed to upload font texture to GPU");
            return;
        }
        
        trace("Text: Font texture uploaded successfully - ID: " + fontTexture.id + " Size: " + fontTexture.width + "x" + fontTexture.height);
        
        // Set up the atlas - we'll use 8x8 as a base size but override UV calculations
        var tileSize = 8;
        trace("Text: About to call setAtlas with texture ID " + fontTexture.id + " and tileSize " + tileSize);
        setAtlas(fontTexture, tileSize);
        trace("Text: setAtlas call completed");
        
        // Parse character data from JSON
        characterMap = new Map();
        var charCount = 0;
        var tileIdCounter = 1;  // Start tile IDs from 1 (0 is empty)
        
        for (charDef in fontData.chars.char) {
            var charCode = Std.parseInt(charDef.id);
            var x = Std.parseInt(charDef.x);
            var y = Std.parseInt(charDef.y);
            var width = Std.parseInt(charDef.width);
            var height = Std.parseInt(charDef.height);
            var xoffset = Std.parseInt(charDef.xoffset);
            var yoffset = Std.parseInt(charDef.yoffset);
            var xadvance = Std.parseInt(charDef.xadvance);
            
            // Assign sequential tile IDs for proper mapping
            var tileId = tileIdCounter++;
            
            characterMap.set(charCode, {
                id: charCode,
                x: x,
                y: y,
                width: width,
                height: height,
                xoffset: xoffset,
                yoffset: yoffset,
                xadvance: xadvance,
                tileId: tileId
            });
            
            charCount++;
            
            // Debug a few characters
            if (charCount <= 5) {
                trace("Text: Char " + charCode + " ('" + String.fromCharCode(charCode) + "') -> Tile " + tileId + " at (" + x + ", " + y + ") size " + width + "x" + height);
            }
        }
        
        trace("Text: Loaded " + charCount + " characters from JSON with proper tile mapping");
    }

    /**
     * Create a basic font mapping for common ASCII characters
     * This is a simplified version - in a full implementation you'd parse the JSON
     */
    private function createBasicFont(fontTextureData:TextureData):Void {
        var fontTexture:Texture = null;
        
        if (fontTextureData != null) {
            // Upload texture to GPU and get Texture object
            fontTexture = __renderer.uploadTexture(fontTextureData);
        }
        
        if (fontTexture == null) {
            trace("Text: Font texture upload failed, creating fallback texture");
            // Create a simple solid white texture as fallback
            var fallbackTextureData = createFallbackTextureData();
            fontTexture = __renderer.uploadTexture(fallbackTextureData);
        }
        
        if (fontTexture == null) {
            trace("Error: Failed to create any texture for font rendering");
            return;
        }
        
        // Set up the atlas using TilemapFast's setAtlas method
        setAtlas(fontTexture, 8);  // 8px character size
        
        trace("Text: Font texture uploaded successfully - ID: " + fontTexture.id + " Size: " + fontTexture.width + "x" + fontTexture.height);
        
        // Create basic character mapping
        // TODO: Parse full JSON data - for now just map some basic characters
        createCharacterMapping();
        
        var charCount = 0;
        for (_ in characterMap.keys()) {
            charCount++;
        }
        trace("Text: Loaded font with " + charCount + " characters");
    }
    
    /**
     * Create a simple fallback texture for text rendering
     */
    private function createFallbackTextureData():TextureData {
        // Create a simple 128x128 white texture with a grid pattern for characters
        var width = 128;
        var height = 128;
        var bytesPerPixel = 4; // RGBA
        var totalBytes = width * height * bytesPerPixel;
        
        // Create texture data using UInt8Array as expected by TextureData
        var pixelData = new haxe.io.UInt8Array(totalBytes);
        
        // Fill with white and create a simple grid pattern
        for (y in 0...height) {
            for (x in 0...width) {
                var pixelIndex = (y * width + x) * bytesPerPixel;
                
                // Create a simple grid pattern for character boundaries (8x8 characters = 16x16 grid)
                var isGridLine = (x % 8 == 0 || y % 8 == 0);
                var brightness = isGridLine ? 200 : 255;
                
                pixelData[pixelIndex + 0] = brightness; // R
                pixelData[pixelIndex + 1] = brightness; // G  
                pixelData[pixelIndex + 2] = brightness; // B
                pixelData[pixelIndex + 3] = 255;        // A
            }
        }
        
        // Create TextureData using the proper constructor
        var textureData = new TextureData(pixelData, bytesPerPixel, width, height, true);
        
        return textureData;
    }
    
    /**
     * Create basic character mappings
     * This is simplified - the real implementation would parse the JSON
     */
    private function createCharacterMapping():Void {
        // Map ASCII characters to tile IDs
        // This is a placeholder - real implementation would use JSON data
        
        // Basic ASCII mapping (A-Z, a-z, 0-9, space, punctuation)
        var chars = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";
        
        for (i in 0...chars.length) {
            var charCode = chars.charCodeAt(i);
            var tileId = i + 1; // Start from tile 1 (0 is empty)
            
            // Create character data (simplified)
            characterMap.set(charCode, {
                id: charCode,
                x: 0, y: 0,  // Will be calculated from tile ID
                width: 6, height: 8,  // Approximate Nokia font size
                xoffset: 0, yoffset: 0,
                xadvance: 6,  // Character width + spacing
                tileId: tileId
            });
        }
        
        trace("Text: Created character mapping for " + chars.length + " characters");
    }
    
    /**
     * Override TilemapFast's getTileUVs to use real bitmap font coordinates
     * This fixes the corrupted text issue by using actual character positions from JSON
     */
    override private function getTileUVs(tileId:Int):Array<Float> {
        // Find the character data for this tile ID
        var charData:CharData = null;
        for (char in characterMap) {
            if (char.tileId == tileId) {
                charData = char;
                break;
            }
        }
        
        if (charData == null) {
            // Fall back to empty UVs for invalid tiles
            return [0.0, 0.0, 0.0, 0.0];
        }
        
        // Use the real character position and size from the font JSON
        var atlasWidth = 128.0;  // Nokia font atlas is 128x128
        var atlasHeight = 128.0;
        
        // Convert pixel coordinates to UV coordinates (0.0 to 1.0)
        var u1 = charData.x / atlasWidth;
        var v1_raw = charData.y / atlasHeight;
        var u2 = (charData.x + charData.width) / atlasWidth;
        var v2_raw = (charData.y + charData.height) / atlasHeight;
        
        // Apply V-coordinate flipping for OpenGL (same as TilemapFast does)
        var v1 = 1.0 - v1_raw;
        var v2 = 1.0 - v2_raw;
        
        trace("Text: Tile " + tileId + " (char " + charData.id + ") -> UV: [" + u1 + ", " + v1 + ", " + u2 + ", " + v2 + "]");
        
        return [u1, v1, u2, v2];
    }

    /**
     * Set the text content and update the display
     */
    public function setText(newText:String):Void {
        if (this.text != newText) {
            this.text = newText;
            updateText();
        }
    }
    
    /**
     * Update the tilemap to display the current text
     */
    private function updateText():Void {
        if (text == null || text.length == 0) {
            // Clear the tilemap for empty text
            clear();
            return;
        }
        
        // Calculate required grid size
        var lines = text.split("\n");
        var maxLineLength = 0;
        for (line in lines) {
            if (line.length > maxLineLength) {
                maxLineLength = line.length;
            }
        }
        
        var gridWidth = maxLineLength;
        var gridHeight = lines.length;
        
        // Resize tilemap if needed
        if (gridWidth != mapWidth || gridHeight != mapHeight) {
            resize(gridWidth, gridHeight);
        }
        
        // Clear existing tiles
        clear();
        
        // Render each character
        var currentY = 0;
        var tilesSet = 0;
        for (line in lines) {
            var currentX = 0;
            
            for (i in 0...line.length) {
                var charCode = line.charCodeAt(i);
                var charData = characterMap.get(charCode);
                
                if (charData != null) {
                    // Set the tile for this character
                    setTile(currentX, currentY, charData.tileId);
                    tilesSet++;
                }
                
                currentX++;
            }
            
            currentY++;
        }
        
        trace("Text: Updated text display - '" + text + "' (" + gridWidth + "x" + gridHeight + ") with " + tilesSet + " tiles set");
        trace("Text: needsBufferUpdate=" + needsBufferUpdate + ", __entireMapDirty=" + __entireMapDirty + ", vertices=" + (__verticesToRender > 0 ? Std.string(__verticesToRender) : "0"));
    }
    
    /**
     * Resize the text grid
     */
    private function resize(newWidth:Int, newHeight:Int):Void {
        this.mapWidth = newWidth;
        this.mapHeight = newHeight;
        
        // Reinitialize tile data array
        tileData = [];
        for (y in 0...mapHeight) {
            tileData[y] = [];
            for (x in 0...mapWidth) {
                tileData[y][x] = 0;  // Empty tile
            }
        }
        
        // Mark for complete rebuild
        __entireMapDirty = true;
        needsBufferUpdate = true;
        
        trace("Text: Resized to " + newWidth + "x" + newHeight);
    }
    
    /**
     * Get the text width in world units
     */
    public function getTextWidth():Float {
        if (text == null || text.length == 0) return 0;
        
        var lines = text.split("\n");
        var maxWidth = 0.0;
        
        for (line in lines) {
            var lineWidth = 0.0;
            for (i in 0...line.length) {
                var charCode = line.charCodeAt(i);
                var charData = characterMap.get(charCode);
                if (charData != null) {
                    lineWidth += charData.xadvance * fontSize;
                }
            }
            if (lineWidth > maxWidth) {
                maxWidth = lineWidth;
            }
        }
        
        return maxWidth;
    }
    
    /**
     * Get the text height in world units
     */
    public function getTextHeight():Float {
        if (text == null || text.length == 0) return 0;
        
        var lines = text.split("\n");
        return lines.length * tileSize * fontSize;
    }
    
    /**
     * Override render to set text color uniform
     */
    override public function render(cameraMatrix:math.Matrix):Void {
        // Set the text color uniform in the uniforms map
        uniforms.set("uColor", color);
        
        // Call parent render method
        super.render(cameraMatrix);
    }
}

/**
 * Font data structure (matches the actual JSON format)
 */
typedef BitmapFont = {
    var info:FontInfo;
    var common:FontCommon;
    var chars:FontChars;
}

typedef FontInfo = {
    var face:String;
    var size:String;
}

typedef FontCommon = {
    var lineHeight:String;
    var base:String;
    var scaleW:String;
    var scaleH:String;
}

typedef FontChars = {
    var count:String;
    var char:Array<CharDataJson>;
}

/**
 * Character data from the JSON (all strings that need parsing)
 */
typedef CharDataJson = {
    var id:String;         // Character code as string
    var x:String;          // X position in atlas as string
    var y:String;          // Y position in atlas as string
    var width:String;      // Character width as string
    var height:String;     // Character height as string
    var xoffset:String;    // X offset for rendering as string
    var yoffset:String;    // Y offset for rendering as string
    var xadvance:String;   // How much to advance cursor as string
}

/**
 * Character data for internal use (parsed to integers)
 */
typedef CharData = {
    var id:Int;        // Character code
    var x:Int;         // X position in atlas
    var y:Int;         // Y position in atlas  
    var width:Int;     // Character width
    var height:Int;    // Character height
    var xoffset:Int;   // X offset for rendering
    var yoffset:Int;   // Y offset for rendering
    var xadvance:Int;  // How much to advance cursor
    var tileId:Int;    // Tile ID in our atlas (calculated)
}