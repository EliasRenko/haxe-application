package gui;

/**
 * Label - Static text display control
 * Renders text using a single tile for background (optional)
 * 
 * This is a simplified implementation for testing
 * Future: Add text rendering via Canvas.textDisplay
 */
class Label extends Control {

    // ** Public Properties

    /** Label text content */
    public var text(get, set):String;

    // ** Private State

    private var __text:String = "";
    private var __bgTileId:Int = -1;
    private var __hasBackground:Bool = false;

    /**
     * Create a new label
     * @param text Label text
     * @param x Label X position
     * @param y Label Y position
     * @param hasBackground Whether to show background tile
     */
    public function new(text:String, x:Float, y:Float, hasBackground:Bool = false) {
        super(x, y);

        __text = text;
        __hasBackground = hasBackground;
        __width = 100;  // Will be calculated from text width later
        __height = 16;  // Standard text height
        __type = 'label';
    }

    /**
     * Initialize label - create background tile if needed
     */
    override function init():Void {
        super.init();

        if (__hasBackground) {
            // Get region ID for label background
            var regionId = ____canvas.getRegionId("label_bg");
            if (regionId == -1) {
                trace("Warning: Label background region not found, using region 0");
                regionId = 0;
            }

            // Add background tile
            __bgTileId = ____canvas.tileBatchFast.addTile(
                __x + ____offsetX,
                __y + ____offsetY,
                __width,
                __height,
                regionId
            );
        }

        // TODO: Add text rendering via Canvas.textDisplay
        trace("Label '" + __text + "' initialized" + (__hasBackground ? " with background" : ""));
    }

    /**
     * Release label - remove tiles
     */
    override function release():Void {
        if (__bgTileId != -1) {
            ____canvas.tileBatchFast.removeTile(__bgTileId);
            __bgTileId = -1;
        }

        // TODO: Remove text from Canvas.textDisplay

        super.release();
    }

    /**
     * Update background tile X position
     */
    override function __setGraphicX():Void {
        if (__bgTileId != -1) {
            var tile = ____canvas.tileBatchFast.tiles.get(__bgTileId);
            if (tile != null) {
                ____canvas.tileBatchFast.updateTile(
                    __bgTileId,
                    __x + ____offsetX,
                    tile.y,
                    tile.width,
                    tile.height,
                    tile.regionId
                );
            }
        }

        // TODO: Update text position
    }

    /**
     * Update background tile Y position
     */
    override function __setGraphicY():Void {
        if (__bgTileId != -1) {
            var tile = ____canvas.tileBatchFast.tiles.get(__bgTileId);
            if (tile != null) {
                ____canvas.tileBatchFast.updateTile(
                    __bgTileId,
                    tile.x,
                    __y + ____offsetY,
                    tile.width,
                    tile.height,
                    tile.regionId
                );
            }
        }

        // TODO: Update text position
    }

    // ** Getters and Setters

    private function get_text():String {
        return __text;
    }

    private function set_text(value:String):String {
        __text = value;
        // TODO: Update text rendering
        return value;
    }
}
