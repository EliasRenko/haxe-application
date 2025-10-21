package states;

import utils.BinPacker;
import sys.FileSystem;
import loaders.TGAExporter;
import data.TextureData;
import Promise;

class AtlasState extends State {
    
    public function new(app:App) {
        super("AtlasState", app);
    }

    override public function init():Void {
        super.init();
        
        // Test: Load and pack tiles from a folder
        trace("AtlasState: Starting atlas packing test...");
        loadTiles("tiles/dev");
    }

    override public function update(elapsed:Float):Void {
        super.update(elapsed);
    }

    public function loadTiles(folder:String):Void {

        var filesToLoad:Array<Promise<Dynamic>> = new Array<Promise<Dynamic>>();

        var names:Array<String> = [];
        var ext:String;
        var files = FileSystem.readDirectory("res/" + folder);
        for (file in files) {
            ext = haxe.io.Path.extension(file);
            if (ext == "tga") {
                filesToLoad.push(app.resources.loadTexture(folder + "/" + file));
            }
        }

        Promise.all(filesToLoad).then(function(textures:Array<TextureData>):Void {
            //trace("Loaded " + textures.length + " textures into atlas.");

            packAtlas(textures);

        }).onError(function(error:String):Void {
            trace("Error loading textures: " + error);
        });
    }

    public function packAtlas(textures:Array<TextureData>):Void {
        var binPacker = new BinPacker(1024, 1024, true);
        
        // Store texture data with their names and packed positions
        var packedTextures:Array<{tex:TextureData, rect:BinRect, name:String}> = [];
        
        // Pack all textures into the bin
        for (i in 0...textures.length) {
            var tex = textures[i];
            
            // Try to pack this texture
            var rect:BinRect = binPacker.insert(
                tex.width, 
                tex.height, 
                true, // merge
                BestAreaFit, 
                ShorterLeftoverAxis
            );
            
            if (rect == null) {
                trace('Warning: Texture $i (${tex.width}x${tex.height}) could not be packed into atlas');
                continue;
            }
            
            packedTextures.push({
                tex: tex,
                rect: rect,
                name: 'texture_$i' // You can pass actual names if available
            });
        }
        
        trace('Packed ${packedTextures.length} textures. Atlas occupancy: ${binPacker.occupancy() * 100}%');
        
        // Create the atlas texture
        var atlasData = createAtlasTexture(1024, 1024, packedTextures);
        
        // Save the atlas as TGA
        TGAExporter.saveToTGA(atlasData, 'res/textures/atlas.tga');
        
        // Save the atlas metadata (region definitions)
        saveAtlasMetadata(packedTextures, 'res/textures/atlas.json');

        trace('Atlas saved to atlas.tga and atlas.json');
    }
    
    /**
     * Create the atlas texture by copying all packed textures into it
     */
    private function createAtlasTexture(width:Int, height:Int, packedTextures:Array<{tex:TextureData, rect:BinRect, name:String}>):TextureData {
        // Create a blank RGBA atlas texture
        var atlasPixels = new haxe.io.UInt8Array(width * height * 4);
        
        // Fill with transparent black
        for (i in 0...(width * height * 4)) {
            atlasPixels[i] = 0;
        }
        
        // Copy each packed texture into the atlas
        for (item in packedTextures) {
            var tex = item.tex;
            var rect = item.rect;
            var x = Std.int(rect.x);
            var y = Std.int(rect.y);
            
            // Copy pixels row by row
            for (row in 0...tex.height) {
                for (col in 0...tex.width) {
                    var srcIdx = (row * tex.width + col) * tex.bytesPerPixel;
                    var dstIdx = ((y + row) * width + (x + col)) * 4;
                    
                    // Copy RGB
                    atlasPixels[dstIdx + 0] = tex.bytes[srcIdx + 0]; // R
                    atlasPixels[dstIdx + 1] = tex.bytes[srcIdx + 1]; // G
                    atlasPixels[dstIdx + 2] = tex.bytes[srcIdx + 2]; // B
                    
                    // Copy or set alpha
                    if (tex.bytesPerPixel == 4) {
                        atlasPixels[dstIdx + 3] = tex.bytes[srcIdx + 3]; // A
                    } else {
                        atlasPixels[dstIdx + 3] = 255; // Opaque
                    }
                }
            }
        }
        
        return new TextureData(atlasPixels, 4, width, height, true);
    }
    
    /**
     * Save atlas metadata to JSON file (only region/tile information)
     */
    private function saveAtlasMetadata(packedTextures:Array<{tex:TextureData, rect:BinRect, name:String}>, filename:String):Void {
        var metadata = {
            atlas: {
                width: 1024,
                height: 1024,
                format: "RGBA"
            },
            regions: []
        };
        
        for (item in packedTextures) {
            metadata.regions.push({
                name: item.name,
                x: Std.int(item.rect.x),
                y: Std.int(item.rect.y),
                width: Std.int(item.rect.width),
                height: Std.int(item.rect.height),
                flipped: item.rect.flipped
            });
        }
        
        var json = haxe.Json.stringify(metadata, null, "  ");
        sys.io.File.saveContent(filename, json);
    }
}