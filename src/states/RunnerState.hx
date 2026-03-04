package states;

import haxe.Json;
import display.ManagedTileBatch;
import entity.DisplayEntity;

/**
 * RunnerState - Loads and renders an editor-exported map (new.json).
 *
 * Flow:
 *  1. Parse the JSON map: tilesets, entity definitions, layers.
 *  2. For each referenced tileset create one ManagedTileBatch backed by its
 *     texture.  If the texture file is missing a fallback is used so the rest
 *     of the map still renders.
 *  3. Tilemap layers  → define atlas regions from 1-based tile indices,
 *     then addTile() for every tile in the layer.
 *  4. Entity layers   → look up each entity's pixel region from its definition,
 *     define the region once per entity type, then addTile() per instance.
 */
class RunnerState extends State {

    // One ManagedTileBatch per tileset name
    private var tileBatches:Map<String, ManagedTileBatch> = new Map();

    // Region caches so we call defineRegion() only once per unique tile/entity
    // tileRegionCache  : tilesetName -> (1-based tile index -> regionId)
    // entityRegionCache: tilesetName -> (entity name       -> regionId)
    private var tileRegionCache:Map<String, Map<Int, Int>>    = new Map();
    private var entityRegionCache:Map<String, Map<String, Int>> = new Map();

    public function new(app:App) {
        super("Runner", app);
    }

    override public function init():Void {
        super.init();

        // Position the camera to roughly centre on the map content
        // (tiles are placed around x=[512,704], y=[352,448] in world space)
        camera.x = 380.0;
        camera.y = 260.0;

        trace("RunnerState: init – loading map");
        loadMap("maps/new.json");
    }

    // -------------------------------------------------------------------------
    //  Map loading entry point
    // -------------------------------------------------------------------------

    private function loadMap(path:String):Void {

        // -- 1. Load JSON text -------------------------------------------------
        var jsonText:String = null;
        try {
            jsonText = app.resources.getText(path);
        } catch (e:Dynamic) {
            trace("RunnerState: cannot load map '" + path + "': " + e);
            return;
        }

        var mapData:Dynamic = Json.parse(jsonText);
        var renderer = app.renderer;

        // Shared shader program for all tile batches
        var vertShader = app.resources.getText("shaders/textured.vert");
        var fragShader = app.resources.getText("shaders/textured.frag");
        var programInfo = renderer.createProgramInfo("textured", vertShader, fragShader);

        // -- 2. Build lookup maps from the JSON --------------------------------

        // entity definitions: name -> Dynamic { regionX, regionY, regionWidth, regionHeight, width, height }
        var entityDefs:Map<String, Dynamic> = new Map();
        for (def in (mapData.entityDefinitions : Array<Dynamic>)) {
            entityDefs.set(cast def.name, def);
        }

        // tileset defs: name -> Dynamic { tileSize, texturePath }
        var tilesetDefs:Map<String, Dynamic> = new Map();
        for (ts in (mapData.tilesets : Array<Dynamic>)) {
            tilesetDefs.set(cast ts.name, ts);
        }

        // -- 3. Create one ManagedTileBatch per tileset ------------------------
        var textureWidths:Map<String, Int> = new Map();

        for (ts in (mapData.tilesets : Array<Dynamic>)) {
            var tsName:String = cast ts.name;

            // Extract the bare filename from the absolute Windows path stored
            // by the editor, e.g. "C:\...\res\textures\devTiles.tga" → "devTiles.tga"
            var rawPath:String  = cast ts.texturePath;
            var normalized      = StringTools.replace(rawPath, "\\", "/");
            var filename        = haxe.io.Path.withoutDirectory(normalized);

            // Try the exact filename first, fall back to dev_tiles.tga
            var textureData:data.TextureData = null;
            try {
                textureData = app.resources.getTexture("textures/" + filename);
            } catch (e:Dynamic) {
                trace("RunnerState: texture '" + filename + "' not preloaded – using fallback (dev_tiles.tga)");
                try {
                    textureData = app.resources.getTexture("textures/dev_tiles.tga");
                } catch (e2:Dynamic) {
                    trace("RunnerState: fallback texture also missing – skipping tileset '" + tsName + "'");
                    continue;
                }
            }

            var texture = renderer.uploadTexture(textureData);
            textureWidths.set(tsName, texture.width);

            var batch = new ManagedTileBatch(programInfo, texture);
            batch.debugName = "tileset_" + tsName;
            batch.init(renderer);

            tileBatches.set(tsName, batch);
            tileRegionCache.set(tsName, new Map());
            entityRegionCache.set(tsName, new Map());

            // Wrap in a DisplayEntity so the State renders it automatically
            addEntity(new DisplayEntity(batch, "tileset_" + tsName));

            trace("RunnerState: tileset '" + tsName + "' → " + filename
                  + "  texture " + texture.width + "×" + texture.height);
        }

        // -- 4. Process layers -------------------------------------------------
        for (layer in (mapData.layers : Array<Dynamic>)) {
            if (!(layer.visible : Bool)) continue;

            var layerType:String = cast layer.type;
            switch (layerType) {
                case "tilemap": processTilemapLayer(layer, tilesetDefs, textureWidths);
                case "entity":  processEntityLayer(layer, entityDefs);
                default:        trace("RunnerState: unknown layer type '" + layerType + "'");
            }
        }

        //trace("RunnerState: map loaded – " + tileBatches.keys() + " tileset batch(es) active");
    }

    // -------------------------------------------------------------------------
    //  Tilemap layer
    // -------------------------------------------------------------------------

    /**
     * Tilemap layer tiles store a 1-based index into the tileset grid.
     * We convert it to pixel coordinates: col/row × tileSize, then define
     * (or reuse) an atlas region and add the tile to the batch.
     */
    private function processTilemapLayer(
            layer:Dynamic,
            tilesetDefs:Map<String, Dynamic>,
            textureWidths:Map<String, Int>):Void {

        var tsName:String = cast layer.tilesetName;
        var batch = tileBatches.get(tsName);
        if (batch == null) {
            trace("RunnerState: no batch for tileset '" + tsName
                  + "' referenced in layer '" + cast(layer.name, String) + "'");
            return;
        }

        // Tile size for this tileset
        var tsDef   = tilesetDefs.get(tsName);
        var tileSize:Int = (tsDef != null) ? Std.int(tsDef.tileSize) : 32;

        // How many tiles fit in one row of the texture atlas
        var texW        = textureWidths.exists(tsName) ? textureWidths.get(tsName) : 128;
        var tilesPerRow = Std.int(texW / tileSize);
        if (tilesPerRow <= 0) tilesPerRow = 1;

        var regionCache = tileRegionCache.get(tsName);
        var tiles:Array<Dynamic> = cast layer.tiles;

        for (tile in tiles) {
            var regionIndex:Int = Std.int(tile.region); // 1-based tile index

            // Define the region the first time we encounter this index
            if (!regionCache.exists(regionIndex)) {
                var idx  = regionIndex - 1;             // convert to 0-based
                if (idx < 0) idx = 0;
                var col    = idx % tilesPerRow;
                var row    = Std.int(idx / tilesPerRow);
                var atlasX = col * tileSize;
                var atlasY = row * tileSize;
                var rId    = batch.defineRegion(atlasX, atlasY, tileSize, tileSize);
                regionCache.set(regionIndex, rId);
            }

            var regionId = regionCache.get(regionIndex);
            batch.addTile(tile.x, tile.y, tileSize, tileSize, regionId);
        }

        trace("RunnerState: tilemap layer '" + cast(layer.name, String)
              + "' → " + tiles.length + " tile(s) from tileset '" + tsName + "'");
    }

    // -------------------------------------------------------------------------
    //  Entity layer
    // -------------------------------------------------------------------------

    /**
     * Entity layers contain one or more batches, each associated with a
     * tileset.  Each instance references a named entity definition that holds
     * the exact pixel region inside the tileset texture.
     */
    private function processEntityLayer(layer:Dynamic, entityDefs:Map<String, Dynamic>):Void {

        var batches:Array<Dynamic> = cast layer.batches;

        for (batchData in batches) {
            var tsName:String  = cast batchData.tilesetName;
            var tileBatch = tileBatches.get(tsName);
            if (tileBatch == null) {
                trace("RunnerState: no batch for entity tileset '" + tsName + "'");
                continue;
            }

            var eRegionCache = entityRegionCache.get(tsName);
            var instances:Array<Dynamic> = cast batchData.entities;

            for (inst in instances) {
                var entityName:String = cast inst.name;
                var def = entityDefs.get(entityName);
                if (def == null) {
                    trace("RunnerState: entity definition '" + entityName + "' not found");
                    continue;
                }

                // Define the region once per entity type (pixel coords from def)
                if (!eRegionCache.exists(entityName)) {
                    var rId = tileBatch.defineRegion(
                        Std.int(def.regionX), Std.int(def.regionY),
                        Std.int(def.regionWidth), Std.int(def.regionHeight));
                    eRegionCache.set(entityName, rId);
                }

                var regionId = eRegionCache.get(entityName);
                tileBatch.addTile(inst.x, inst.y, Std.int(def.width), Std.int(def.height), regionId);
            }
        }

        trace("RunnerState: entity layer '" + cast(layer.name, String) + "' processed");
    }

    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
    }
}
