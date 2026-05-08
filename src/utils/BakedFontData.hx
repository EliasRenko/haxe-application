package utils;
#if cpp
import sys.io.File;
#end
import haxe.Json;
import loaders.TGAExporter;
import data.TextureData;

/**
 * One font face inside a (potentially shared) atlas.
 * Mirrors exactly the per-face data that FontLoader.load() consumes.
 */
typedef BakedFace = {
    var fontName:String;
    var fontSize:Int;
    var lineHeight:Int;
    var base:Int;
    var chars:Array<Dynamic>;
    var metrics:Dynamic;
}

/**
 * BakedFontData - Holds all font data and texture in memory.
 *
 * A single instance may represent one font (faces.length == 1, backward-compat)
 * or multiple fonts/sizes packed into the same atlas (faces.length > 1).
 *
 * The convenience fields fontName/fontSize/lineHeight/base/chars/metrics still
 * refer to faces[0] so all existing single-font call sites keep working.
 */
class BakedFontData {
    // ── Shared atlas ──────────────────────────────────────────────────────────
    public var atlasWidth:Int;
    public var atlasHeight:Int;
    public var textureData:TextureData;

    // ── All packed faces ──────────────────────────────────────────────────────
    public var faces:Array<BakedFace>;

    // ── Backward-compat accessors (delegate to faces[0]) ─────────────────────
    public var fontName(get, never):String;
    public var fontSize(get, never):Int;
    public var lineHeight(get, never):Int;
    public var base(get, never):Int;
    public var chars(get, never):Array<Dynamic>;
    public var metrics(get, never):Dynamic;

    private function get_fontName():String  return faces[0].fontName;
    private function get_fontSize():Int     return faces[0].fontSize;
    private function get_lineHeight():Int   return faces[0].lineHeight;
    private function get_base():Int         return faces[0].base;
    private function get_chars():Array<Dynamic> return faces[0].chars;
    private function get_metrics():Dynamic  return faces[0].metrics;

    public function new(atlasWidth:Int, atlasHeight:Int, textureData:TextureData,
                        faces:Array<BakedFace>) {
        this.atlasWidth  = atlasWidth;
        this.atlasHeight = atlasHeight;
        this.textureData = textureData;
        this.faces       = faces;
    }
    
    /**
     * Export faces[0] to JSON + TGA — identical output to the old single-font
     * implementation.  All existing call sites continue to work unchanged.
     *
     * @param basePath  Base output path without extension, e.g. "res/fonts/arial_20"
     */
    public function exportToFiles(basePath:String):Void {
        var lastSlash = Std.int(Math.max(basePath.lastIndexOf("/"), basePath.lastIndexOf("\\\\")));
        var fileName  = basePath.substring(lastSlash + 1);
        _exportFace(faces[0], fileName + ".tga", basePath + ".json");

        var tgaPath = basePath + ".tga";
        TGAExporter.saveToTGA(textureData, tgaPath);
        trace("BakedFontData: Saved atlas to " + tgaPath);
    }

    /**
     * Export all faces to individual JSON files + one shared TGA atlas.
     *
     * Each JSON is in the same format that FontLoader.load() already reads, so
     * existing import code is 100% compatible.
     *
     * Files written:
     *   <outDir>/<atlasName>.tga            — shared pixel atlas
     *   <outDir>/<face.fontName>_<size>.json — one per face
     *
     * @param outDir    Output directory path (e.g. "res/fonts")
     * @param atlasName TGA filename without extension (e.g. "myfont_atlas")
     */
    public function exportAllFaces(outDir:String, atlasName:String):Void {
        var tgaFile = atlasName + ".tga";
        var tgaPath = outDir + "/" + tgaFile;
        TGAExporter.saveToTGA(textureData, tgaPath);
        trace("BakedFontData: Saved shared atlas to " + tgaPath);

        for (face in faces) {
            var jsonPath = outDir + "/" + face.fontName + "_" + face.fontSize + ".json";
            _exportFace(face, tgaFile, jsonPath);
        }
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    private function _exportFace(face:BakedFace, atlasFileName:String, jsonPath:String):Void {
        var jsonData = {
            font: {
                info: {
                    "_face": face.fontName,
                    "_size": Std.string(face.fontSize),
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
                    "_lineHeight": Std.string(face.lineHeight),
                    "_base": Std.string(face.base),
                    "_scaleW": Std.string(atlasWidth),
                    "_scaleH": Std.string(atlasHeight),
                    "_pages": "1",
                    "_packed": "0",
                    "_alphaChnl": "0",
                    "_redChnl": "4",
                    "_greenChnl": "4",
                    "_blueChnl": "4"
                },
                metrics: face.metrics,
                pages: {
                    page: {
                        "_id": "0",
                        "_file": atlasFileName
                    }
                },
                chars: {
                    char: face.chars
                }
            }
        };

        var jsonString = Json.stringify(jsonData, null, "  ");
        File.saveContent(jsonPath, jsonString);
        trace("BakedFontData: Saved face JSON to " + jsonPath);
    }
}
