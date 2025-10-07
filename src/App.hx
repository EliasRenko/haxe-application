package;

class App extends Runtime {
    
    // State Management
    public var states:Array<State> = [];
    public var currentState:State = null;

    // Publics
    public var input(get, null):Input;
    public var resources(get, null):Resources;
    public var log(get, null):Log;

    // Privates
    private var __input:Input;
    private var __resources:Resources;

    public function new() {
        super();

        __log = new Log(this);
        __resources = new Resources(this);
        __input = new Input(this);
    }

    override function init():Bool {
        return super.init();
    }

    override function release():Void {

        // Release current state
        if (currentState != null) {
            currentState.release();
        }

        for (state in states) {
            state.clearEntities(__renderer);
        }

        states = [];
        currentState = null;

        // Release resources first
        if (__resources != null) {
            __resources.release();
            __resources = null;
        }

        // Release input system
        if (__input != null) {
            __input.release();
            __input = null;
        }

        super.release();
    }

    override public function run():Void {
        super.run();
    }

    override function preload() {
        super.preload();

        // TODO: Move to a more appropriate place
        __renderer = new Renderer(this, 640, 480);

        resources.loadText("preload.txt")
            .then(function(source:String) {
                var files:Array<Promise<Dynamic>> = new Array<Promise<Dynamic>>();
                var lines:Array<String> = source.split("\n");
                var regex:EReg = ~/[^\s]+/;

                for (line in lines) {
                    // Skip empty lines and comments
                    line = StringTools.trim(line);
                    if (line.length == 0 || line.charAt(0) == "#") {
                        continue;
                    }
                    
                    if (regex.match(line)) {
                        var path:String = regex.matched(0);
                        var ext = haxe.io.Path.extension(path);
                        switch (ext) {
                            case "tga": {
                                files.push(__resources.loadTexture(path));
                            }
                            case "vert" | "frag": {
                                files.push(__resources.loadText(path));
                            }
                            default: {
                                //files.push(__resources.loadText(path));
                                throw 'Unsupported resource type: ' + ext + ' for file: ' + path;
                            }
                        }
                    }
                }
                
                // Wait for all assets to load
                Promise.all(files)
                    .then(function(results:Array<Dynamic>) {
                        __log.engineInfo("Successfully preloaded " + results.length + " assets");

                        // // Add both states but start with the TilemapFast state for visual demo
                        // __log.engineInfo("Setting up states...");
                        // var logTestState = new states.LogTestState(this);
                        // addState(logTestState);
                        
                        // // Add and activate TilemapFastTestState for immediate visual feedback
                        // var tilemapFastState = new states.TilemapFastTestState(this);
                        // addState(tilemapFastState);
                        
                        // // Activate the TilemapFastTestState to start rendering
                        // switchToState(tilemapFastState);
                    })
                    .onError(function(error:String) {
                        __log.engineError("Failed to preload some assets: " + error);
                    });
            })
            .onError(function(error:String) {
                __log.engineError("Failed to load preload.txt: " + error);
            });
        
        __log.engineInfo("Application initialized successfully!");
    }

    // ===== STATE MANAGEMENT METHODS =====

    /**
     * Add a state to the states array
     */
    public function addState(state:State):State {
        if (state == null) {
            __log.engineWarn("Warning: Attempted to add null state");
            return null;
        }
        
        states.push(state);
        __log.engineInfo("Added state '" + state.name + "' to app (total states: " + states.length + ")");
        
        // If no current state, make this the current one
        if (currentState == null) {
            switchToState(state);
        }
        
        return state;
    }
    
    /**
     * Remove a state from the states array
     */
    public function removeState(state:State):Bool {
        if (state == null) return false;
        
        var removed = states.remove(state);
        if (removed) {
            __log.engineInfo("Removed state '" + state.name + "' from app");
            
            // If this was the current state, release it
            if (currentState == state) {
                currentState.release();
                currentState = null;
                
                // Switch to first available state if any
                if (states.length > 0) {
                    switchToState(states[0]);
                }
            }
            
            // Clean up the state
            state.clearEntities(__renderer);
        }
        
        return removed;
    }
    
    /**
     * Remove state by name
     */
    public function removeStateByName(name:String):Bool {
        for (state in states) {
            if (state.name == name) {
                return removeState(state);
            }
        }
        return false;
    }
    
    /**
     * Switch to a specific state
     */
    public function switchToState(state:State):Bool {
        if (state == null) {
            trace("Warning: Attempted to switch to null state");
            return false;
        }
        
        // Check if state exists in our states array
        var stateExists = false;
        for (s in states) {
            if (s == state) {
                stateExists = true;
                break;
            }
        }
        
        if (!stateExists) {
            __log.engineWarn("Warning: Attempted to switch to state '" + state.name + "' that is not in states array");
            return false;
        }
        
        // Release current state
        if (currentState != null) {
            currentState.release();
        }
        
        // Switch to new state
        currentState = state;
        currentState.init();
        
        __log.engineInfo("Switched to state '" + state.name + "'");
        return true;
    }
    
    /**
     * Switch to state by name
     */
    public function switchToStateByName(name:String):Bool {
        for (state in states) {
            if (state.name == name) {
                return switchToState(state);
            }
        }
        __log.engineWarn("Warning: State '" + name + "' not found");
        return false;
    }
    
    /**
     * Get state by name
     */
    public function getState(name:String):State {
        for (state in states) {
            if (state.name == name) {
                return state;
            }
        }
        return null;
    }

    override function update():Void {
        
        // Use a fixed deltaTime for stable animation (60 FPS target)
        var deltaTime:Float = 1.0 / 60.0; // 0.0167 seconds per frame
        
        // Update input system
        if (__input != null) {
            __input.update();
        }
        
        // Update current state if one is active
        if (currentState != null && currentState.active) {
            currentState.update(deltaTime);
        }
        
        // Post-update input (clear pressed/released states)
        if (__input != null) {
            __input.postUpdate();
        }
    }

    override function render():Void {
       
        __renderer.clearScreen();
        __renderer.initializeRenderState();
        
        if (currentState != null && currentState.active) {
            currentState.render(__renderer);
        }
    }

    // // Keyboard event handlers
    override function onKeyDown(keycode:Int, scancode:Int, repeat:Bool, mod:Int, windowId:Int):Void {
        #if use_scancodes
        @:privateAccess __input.keyboard.onKeyDown(scancode, repeat, mod);
        #else
        @:privateAccess __input.keyboard.onKeyDown(keycode, repeat, mod);
        #end
    }

    override function onKeyUp(keycode:Int, scancode:Int, repeat:Bool, mod:Int, windowId:Int):Void {
        #if use_scancodes
        @:privateAccess __input.keyboard.onKeyUp(scancode, repeat, mod);
        #else
        @:privateAccess __input.keyboard.onKeyUp(keycode, repeat, mod);
        #end
    }

    // Getters and setters
    public function get_input():Input {
        return __input;
    }

    public function get_resources():Resources {
        return __resources;
    }

    public function get_log():Log {
        return __log;
    }
}