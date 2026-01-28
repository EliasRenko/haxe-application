package utils;

import sys.io.File;
import haxe.Json;
import loaders.TGAExporter;
import data.TextureData;

/**
 * BakedFontData - Holds all font data and texture in memory
 * 
 * This class encapsulates the result of baking a TrueType font into a bitmap atlas.
 * It can be used directly for rendering or exported to JSON/TGA files on disk.
 */
class BakedFontData {
    public var fontName:String;
    public var fontSize:Int;
    public var atlasWidth:Int;
    public var atlasHeight:Int;
    public var lineHeight:Int;
    public var base:Int;
    public var textureData:TextureData;
    public var chars:Array<Dynamic>;
    public var metrics:Dynamic;
    
    public function new(fontName:String, fontSize:Int, atlasWidth:Int, atlasHeight:Int, 
                       lineHeight:Int, base:Int, textureData:TextureData, 
                       chars:Array<Dynamic>, metrics:Dynamic) {
        this.fontName = fontName;
        this.fontSize = fontSize;
        this.atlasWidth = atlasWidth;
        this.atlasHeight = atlasHeight;
        this.lineHeight = lineHeight;
        this.base = base;
        this.textureData = textureData;
        this.chars = chars;
        this.metrics = metrics;
    }
    
    /**
     * Export this baked font to JSON and TGA files
     * 
     * @param outputName Output name without extension (e.g., "nokiafc22_16")
     */
    public function exportToFiles(outputName:String):Void {
        var atlasFileName = outputName + ".tga";
        
        var jsonData = {
            font: {
                info: {
                    "_face": fontName,
                    "_size": Std.string(fontSize),
                    "_bold": "0",
                    "_italic": "0",
                    "_charset": "",
                    "_unicode": "1",
                    "_stretchH": "100",
                    "_smooth": "0",
                    "_aa": "1",
                    "_padding": "1,1,1,1",
                    "_spacing": "1,1",
                    "_outline": "0"
                },
                common: {
                    "_lineHeight": Std.string(lineHeight),
                    "_base": Std.string(base),
                    "_scaleW": Std.string(atlasWidth),
                    "_scaleH": Std.string(atlasHeight),
                    "_pages": "1",
                    "_packed": "0",
                    "_alphaChnl": "0",
                    "_redChnl": "4",
                    "_greenChnl": "4",
                    "_blueChnl": "4"
                },
                metrics: metrics,
                pages: {
                    page: {
                        "_id": "0",
                        "_file": atlasFileName
                    }
                },
                chars: {
                    char: chars
                }
            }
        };
        
        // Save metadata JSON
        var jsonPath = "res/fonts/" + outputName + ".json";
        var jsonString = Json.stringify(jsonData, null, "  ");
        File.saveContent(jsonPath, jsonString);
        trace("BakedFontData: Saved metadata to " + jsonPath);
        
        // Save atlas texture
        var tgaPath = "res/fonts/" + outputName + ".tga";
        TGAExporter.saveToTGA(textureData, tgaPath);
        trace("BakedFontData: Saved atlas to " + tgaPath);
    }
}
