package states;

import State;
import App;
import Renderer;
import ProgramInfo;
import display.Grid;
import entity.DisplayEntity;

/**
 * Editor state with just an infinite grid for visual reference
 * Minimal state for level editing and scene construction
 */
class EditorState extends State {
    
    private var grid:Grid;
    
    public function new(app:App) {
        super("EditorState", app);
    }
    
    override public function init():Void {
        super.init();
        
        trace("EditorState: Initializing");
        
        // Setup camera for 2D orthographic view
        camera.ortho = true;
        
        // Get renderer
        var renderer = app.renderer;
        
        // Create infinite grid for visual reference
        var gridVertShader = app.resources.getText("shaders/grid.vert");
        var gridFragShader = app.resources.getText("shaders/grid.frag");
        var gridProgramInfo = renderer.createProgramInfo("grid", gridVertShader, gridFragShader);
        
        grid = new Grid(gridProgramInfo, 5000.0); // 5000 unit quad
        grid.gridSize = 128.0; // 128 pixel large grid
        grid.subGridSize = 32.0; // 32 pixel small grid
        grid.setGridColor(0.2, 0.4, 0.6); // Blue-ish grid lines
        grid.setBackgroundColor(0.05, 0.05, 0.1); // Dark blue background
        grid.fadeDistance = 3000.0;
        grid.z = -1.0; // Place grid behind other objects
        grid.init(renderer);
        
        var gridEntity = new DisplayEntity(grid, "grid");
        addEntity(gridEntity);
        
        trace("EditorState: Setup complete");
    }
    
    override public function update(deltaTime:Float):Void {
        super.update(deltaTime);
    }
    
    override public function release():Void {
        super.release();
    }
}
