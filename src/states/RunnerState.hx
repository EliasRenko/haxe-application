package states;

import haxe.Json;
import display.ManagedTileBatch;
import entity.DisplayEntity;
import entity.EntityRegistry;
import entity.EntityClasses;
import lighting.LightingSystem;
import lighting.LightSource;
import display.DarkOverlay;

/**
 * RunnerState - Loads and renders a map exported by the editor.
 *
 * Flow:
 *  1. Load the project file (TestProject.json) to extract tileset definitions
 *     and entity definitions.
 *  2. Load the level file (e.g. default.json) for map bounds and layer data.
 *  3. For each referenced tileset create one ManagedTileBatch backed by its
 *     texture.  If the texture file is missing a fallback is used so the rest
 *     of the map still renders.
 *  4. Tilemap layers  → tiles use gridX/gridY; convert to pixel coords via
 *     tileSize, define atlas regions from 1-based tile indices, then addTile().
 *  5. Entity layers   → entity instances use normalized x/y (0–1); convert to
 *     pixel coords via mapBounds width/height, look up the entity definition
 *     from the project file, define the region once, then addTile() per instance.
 */
class RunnerState extends State {

    // One ManagedTileBatch per tileset name
    private var tileBatches:Map<String, ManagedTileBatch> = new Map();

    // Lighting
    private var lightingSystem:LightingSystem = new LightingSystem();
    private var testLight:LightSource = null;

    // Dark ambient overlay rendered between tiles and lights.
    // Change ambientDarkness (0–1) at any time to adjust world visibility.
    public var ambientDarkness:Float = 0.85;
    private var _darkOverlay:DarkOverlay = null;

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

        trace("RunnerState: init – loading project + map");
        loadMap("TestProject.json", "maps/default.json");
    }

    // -------------------------------------------------------------------------
    //  Map loading entry point
    // -------------------------------------------------------------------------

    private function loadMap(projectPath:String, levelPath:String):Void {

        // Ensure all self-registering entity classes have fired their static
        // initializers before we start parsing entity layers.
        EntityClasses.init();
        trace("EntityRegistry: registered classes → " + EntityRegistry.getRegistered());

        // -- 1. Load and parse the project file --------------------------------
        var projectText:String = null;
        try {
            projectText = app.loadBytes(projectPath).toString();
        } catch (e:Dynamic) {
            trace("RunnerState: cannot load project '" + projectPath + "': " + e);
            return;
        }
        var projectData:Dynamic = Json.parse(projectText);
        var project:Dynamic     = projectData.project;

        // -- 2. Load and parse the level file ----------------------------------
        var levelText:String = null;
        try {
            levelText = app.resources.getText(levelPath);
        } catch (e:Dynamic) {
            trace("RunnerState: cannot load level '" + levelPath + "': " + e);
            return;
        }
        var levelData:Dynamic = Json.parse(levelText);
        var mapData:Dynamic   = levelData.map;

        var renderer = app.renderer;

        // Shared shader program for all tile batches
        var vertShader   = app.resources.getText("shaders/textured.vert");
        var fragShader   = app.resources.getText("shaders/textured.frag");
        var programInfo  = renderer.createProgramInfo("textured", vertShader, fragShader);

        // -- 3. Build lookup maps from the project file ------------------------

        // entity definitions: name -> Dynamic { regionX, regionY, regionWidth, regionHeight, width, height, tilesetName }
        var entityDefs:Map<String, Dynamic> = new Map();
        for (def in (project.entityDefinitions : Array<Dynamic>)) {
            entityDefs.set(cast def.name, def);
        }

        // tileset defs: name -> Dynamic { texturePath, name }
        var tilesetDefs:Map<String, Dynamic> = new Map();
        for (ts in (project.tilesets : Array<Dynamic>)) {
            tilesetDefs.set(cast ts.name, ts);
        }

        // Map bounds: origin offset + size + tile size
        var bounds:Dynamic  = mapData.mapBounds;
        var mapX:Float      = bounds.x;
        var mapY:Float      = bounds.y;
        var mapWidth:Float  = bounds.width;
        var mapHeight:Float = bounds.height;
        var tileSize:Int    = bounds.tileSizeX;

        // Align camera to the map's world-space origin
        camera.x = mapX;
        camera.y = mapY;

        // Prime the lighting system with the map boundaries.
        lightingSystem.setBounds(mapX, mapY, mapWidth, mapHeight);
        

        // -- 4. Create one ManagedTileBatch per tileset ------------------------
        var textureWidths:Map<String, Int> = new Map();

        for (ts in (project.tilesets : Array<Dynamic>)) {
            var tsName:String = cast ts.name;

            // texturePath is the bare relative path stored by the editor,
            // e.g. "textures/devTiles.tga" – extract just the filename.
            var rawPath:String = cast ts.texturePath;
            var normalized     = StringTools.replace(rawPath, "\\", "/");
            var filename       = haxe.io.Path.withoutDirectory(normalized);

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

        // -- 5. Process layers -------------------------------------------------
        // tileSize is captured here so processTilemapLayer can pass it on to the
        // lighting system; the closure over `tileSize` is intentional.
        for (layer in (mapData.layers : Array<Dynamic>)) {
            if (!(layer.visible : Bool)) continue;

            var layerType:String = cast layer.type;
            switch (layerType) {
                case "tilemap": processTilemapLayer(layer, tilesetDefs, textureWidths, tileSize, mapX, mapY);
                case "entity":  processEntityLayer(layer, entityDefs, mapX, mapY, mapWidth, mapHeight);
                default:        trace("RunnerState: unknown layer type '" + layerType + "'");
            }
        }

        // -- 6. Build lighting geometry and add a test light -----------------
        lightingSystem.build();

        // Dark overlay sits between the tile batches and the light meshes so
        // that additive light polygons punch through the darkness.
        var lineVertShader = app.resources.getText("shaders/line.vert");
        var lineFragShader = app.resources.getText("shaders/line.frag");
        var overlayProgram = renderer.createProgramInfo("line", lineVertShader, lineFragShader);
        _darkOverlay = new DarkOverlay(overlayProgram, ambientDarkness);
        _darkOverlay.init(renderer);
        addEntity(new DisplayEntity(_darkOverlay, "dark_overlay"));

        var lightVertShader  = app.resources.getText("shaders/light.vert");
        var lightFragShader  = app.resources.getText("shaders/light.frag");
        var lightProgramInfo = renderer.createProgramInfo("light", lightVertShader, lightFragShader);

        // Place a warm-white test light at the centre of the map.
        // Radius is half the shorter map dimension so it covers a meaningful area.
        var lightRadius = Math.min(mapWidth, mapHeight) * 1;
        testLight = lightingSystem.addLight(
            renderer, lightProgramInfo,
            mapX + mapWidth  * 0.5,
            mapY + mapHeight * 0.5,
            lightRadius);
        addEntity(new DisplayEntity(testLight.mesh, "light_0"));

        trace("RunnerState: map loaded");
    }

    // -------------------------------------------------------------------------
    //  Tilemap layer
    // -------------------------------------------------------------------------

    /**
     * Tilemap layer tiles store a 1-based region index and a gridX/gridY
     * position.  We convert grid coords to pixel coords via tileSize (from
     * mapBounds), then define (or reuse) an atlas region and add the tile.
     */
    private function processTilemapLayer(
            layer:Dynamic,
            tilesetDefs:Map<String, Dynamic>,
            textureWidths:Map<String, Int>,
            tileSize:Int,
            mapX:Float,
            mapY:Float):Void {

        var tsName:String = cast layer.tilesetName;
        var batch = tileBatches.get(tsName);
        if (batch == null) {
            trace("RunnerState: no batch for tileset '" + tsName
                  + "' referenced in layer '" + cast(layer.name, String) + "'");
            return;
        }

        // How many tiles fit in one row of the texture atlas
        var texW        = textureWidths.exists(tsName) ? textureWidths.get(tsName) : 128;
        var tilesPerRow = Std.int(texW / tileSize);
        if (tilesPerRow <= 0) tilesPerRow = 1;

        var regionCache = tileRegionCache.get(tsName);
        var half:Float          = tileSize * 0.5;
        var tiles:Array<Dynamic> = cast layer.tiles;

        for (tile in tiles) {
            var regionIndex:Int = Std.int(tile.region); // 1-based tile index

            // Define the atlas region the first time we encounter this index
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

            // gridX/gridY are tile-grid coordinates; convert to pixel coords
            // and offset by the map's world-space origin.
            var pixelX:Float = mapX + Std.int(tile.gridX) * tileSize;
            var pixelY:Float = mapY + Std.int(tile.gridY) * tileSize;

            var regionId = regionCache.get(regionIndex);
            batch.addTile(pixelX, pixelY, tileSize, tileSize, regionId);

            // Register this tile as a light occluder (centre + half-size).
            lightingSystem.addTile(pixelX + half, pixelY + half, half);
        }

        trace("RunnerState: tilemap layer '" + cast(layer.name, String)
              + "' → " + tiles.length + " tile(s) from tileset '" + tsName + "'");
    }

    // -------------------------------------------------------------------------
    //  Entity layer
    // -------------------------------------------------------------------------

    /**
     * Entity layers contain instances whose x/y are normalized (0–1) relative
     * to the map bounds.  The tileset to use is stored on the entity definition
     * in the project file (def.tilesetName).  We denormalize positions using
     * the supplied mapWidth/mapHeight before placing each tile.
     */
    private function processEntityLayer(
            layer:Dynamic,
            entityDefs:Map<String, Dynamic>,
            mapX:Float,
            mapY:Float,
            mapWidth:Float,
            mapHeight:Float):Void {

        var batches:Array<Dynamic> = cast layer.batches;

        for (batchData in batches) {
            var instances:Array<Dynamic> = cast batchData.entities;

            for (inst in instances) {
                var entityName:String = cast inst.name;
                var def = entityDefs.get(entityName);
                if (def == null) {
                    trace("RunnerState: entity definition '" + entityName + "' not found");
                    continue;
                }

                // The tileset for this entity is declared in its project definition
                var tsName:String = cast def.tilesetName;
                var tileBatch = tileBatches.get(tsName);
                if (tileBatch == null) {
                    trace("RunnerState: no batch for entity tileset '" + tsName
                          + "' (entity '" + entityName + "')");
                    continue;
                }

                var eRegionCache = entityRegionCache.get(tsName);

                // Define the atlas region once per entity type
                if (!eRegionCache.exists(entityName)) {
                    var rId = tileBatch.defineRegion(
                        Std.int(def.regionX), Std.int(def.regionY),
                        Std.int(def.regionWidth), Std.int(def.regionHeight));
                    eRegionCache.set(entityName, rId);
                }

                // Denormalize position: inst.x/y is the position of the entity's
                // logical pivot point in normalized [0,1] map space.  Subtract the
                // definition's pivot (e.g. 0.5/0.5 = centre) scaled to pixel size
                // to convert from pivot-point to top-left corner.
                var defPivotX:Float = (def.pivotX != null) ? def.pivotX : 0.0;
                var defPivotY:Float = (def.pivotY != null) ? def.pivotY : 0.0;
                var pixelX:Float = mapX + inst.x * mapWidth  - defPivotX * Std.int(def.width);
                var pixelY:Float = mapY + inst.y * mapHeight - defPivotY * Std.int(def.height);

                // Stamp resolved values onto inst so factories can use them
                var regionId = eRegionCache.get(entityName);
                Reflect.setField(inst, "regionId", regionId);
                Reflect.setField(inst, "pixelX", pixelX);
                Reflect.setField(inst, "pixelY", pixelY);

                // If the definition carries a "class" name and a factory is
                // registered, delegate everything (tile creation included) to
                // the factory.  Otherwise fall back to a plain visual tile.
                var className:String = cast Reflect.field(def, "class");
                if (className != null && EntityRegistry.has(className)) {
                    var ent = EntityRegistry.create(className, tileBatch, inst, def);
                    if (ent != null) {
                        addEntity(ent);
                        trace("RunnerState: spawned '" + className + "' at ("
                              + pixelX + "," + pixelY + ")");
                    }
                } else {
                    // No registered class — just place a static visual tile.
                    tileBatch.addTile(pixelX, pixelY, Std.int(def.width), Std.int(def.height), regionId);
                }
            }
        }

        trace("RunnerState: entity layer '" + cast(layer.name, String) + "' processed");
    }

    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);

        // On left-click, move the test light to the clicked world position.
        var mouse = app.input.mouse;
        if (testLight != null && mouse.check(1)) {
            // Unproject: screen pixel → world space (ortho, no rotation).
            testLight.x = camera.x + mouse.x / camera.zoom;
            testLight.y = camera.y + mouse.y / camera.zoom;
        }

        // Rebuild the dark overlay to cover the current camera viewport.
        if (_darkOverlay != null) {
            _darkOverlay.ambientDarkness = ambientDarkness;
            var size = app.window.size;
            _darkOverlay.rebuild(
                camera.x,
                camera.y,
                camera.x + size.x / camera.zoom,
                camera.y + size.y / camera.zoom);
        }

        lightingSystem.update();
    }
}
