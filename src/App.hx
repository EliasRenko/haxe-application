package;

import Log.LogCategory;

class App extends Runtime {
    
    // State Management
    public var states:Array<State> = [];
    public var currentState:State = null;

    // Publics
    public var input(get, null):Input;
    public var resources(get, null):Resources;
    public var log(get, null):Log;
    public var renderer(get, null):Renderer;

    // Privates
    private var __input:Input;
    private var __resources:Resources;
    private var __renderer:Renderer;
    private var __log:Log;

    private var __lastTime:Float = 0.0;
    private var __currentTime:Float = 0.0;

    public function new() {
        super();
    }

    override function init():Bool {
        super.init();

        __log = new Log(this #if debug , true #end);
        __resources = new Resources(this);
        __input = new Input(this);
        __renderer = new Renderer(this);

        __log.debug(LogCategory.APP, "App initialized in debug mode");

        preload();

        // Initialize timing
        __lastTime = SDL.getTicks() / 1000.0;
        
        // Initialize post-processing framebuffer
        __renderer.initializePostProcessing();
        __renderer.usePostProcessing = true; // Enable post-processing by default

        return true;
    }

    override function release():Void {
        if (currentState != null) {
            currentState.release();
        }

        for (state in states) {
            state.clearEntities(__renderer);
        }

        states = [];
        currentState = null;

        __input.release();
        __renderer.release();
        __resources.release();

        var success = saveBytes("output.txt", __log.logHistory);

        __log.release();

        super.release();
    }

    /**
     * Add a state to the states array
     */
    public function addState(state:State):State {
        if (state == null) {
            __log.warn(LogCategory.APP,"Warning: Attempted to add null state");
            return null;
        }
        
        states.push(state);
        __log.info(LogCategory.APP,"Added state '" + state.name + "' to app (total states: " + states.length + ")");
        
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
            __log.info(LogCategory.APP, "Removed state '" + state.name + "' from app");
            
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
            __log.warn(LogCategory.APP, "Warning: Attempted to switch to state '" + state.name + "' that is not in states array");
            return false;
        }
        
        // Release current state
        if (currentState != null) {
            currentState.release();
        }
        
        // Switch to new state
        currentState = state;
        currentState.init();

        __log.info(LogCategory.APP, "Switched to state '" + state.name + "'");

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
        __log.warn(LogCategory.APP, "Warning: State '" + name + "' not found");
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
        // Calculate actual deltaTime based on elapsed time
        __currentTime = SDL.getTicks() / 1000.0; // Convert milliseconds to seconds
        var deltaTime:Float = __currentTime - __lastTime;
        __lastTime = __currentTime;
        
        // Clamp deltaTime to prevent huge jumps (e.g., when debugging or window dragging)
        if (deltaTime > 0.1) {
            deltaTime = 1.0 / 60.0; // Cap at ~60 FPS
        }
        
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
        __renderer.render();
        if (__renderer.usePostProcessing) {
            // STEP 1: Render scene to framebuffer
            __renderer.bindFramebuffer();
            __renderer.clearScreen();
            //GL.glClear(GL.COLOR_BUFFER_BIT | GL.DEPTH_BUFFER_BIT);
            __renderer.initializeRenderState();
            
            if (currentState != null && currentState.active) {
                currentState.render(__renderer);
            }
            
            // STEP 2: Render framebuffer to screen with post-processing
            __renderer.unbindFramebuffer();
            __renderer.clearScreen(); // Clear the screen framebuffer
            
            __renderer.renderToScreen();
        } else {
            // Direct rendering (no post-processing)
            __renderer.clearScreen();
            __renderer.initializeRenderState();
            
            if (currentState != null && currentState.active) {
                currentState.render(__renderer);
            }
        }
    }

    // Keyboard event handlers
    override function onKeyDown(keycode:Int, scancode:Int, repeat:Bool, mod:Int, windowId:Int):Void {
        #if use_scancodes
        @:privateAccess __input.keyboard.onKeyDown(scancode, repeat, mod);
        log.info(LogCategory.INPUT, "Key down: " + scancode);
        #else
        @:privateAccess __input.keyboard.onKeyDown(keycode, repeat, mod);
        log.info(LogCategory.INPUT, "Key down: " + keycode);
        #end
    }

    override function onKeyUp(keycode:Int, scancode:Int, repeat:Bool, mod:Int, windowId:Int):Void {
        #if use_scancodes
        @:privateAccess __input.keyboard.onKeyUp(scancode, repeat, mod);
        log.info(LogCategory.INPUT, "Key up: " + scancode);
        #else
        @:privateAccess __input.keyboard.onKeyUp(keycode, repeat, mod);
        log.info(LogCategory.INPUT, "Key up: " + keycode);
        #end
    }

    // Mouse event handlers
    override function onMouseButtonDown(x:Float, y:Float, button:Int, windowId:Int):Void {
        @:privateAccess __input.mouse.onButtonDown(x, y, button);
        log.info(LogCategory.INPUT, "Mouse button " + button + " down at (" + x + ", " + y + ")");
    }

    override function onMouseButtonUp(x:Float, y:Float, button:Int, windowId:Int):Void {
        @:privateAccess __input.mouse.onButtonUp(x, y, button);
        log.info(LogCategory.INPUT, "Mouse button " + button + " up at (" + x + ", " + y + ")");
    }

    override function onMouseMotion(x:Float, y:Float, xrel:Float, yrel:Float, windowId:Int):Void {
        @:privateAccess __input.mouse.onMouseMotion(x, y, xrel, yrel);
    }

    // Window event handlers
    override function onWindowResized(windowId:Int, width:Int, height:Int):Void {
        renderer.resize(width, height);

        for (state in states) {
            state.onWindowResized(width, height);
        }
    }

    // DLL API methods - expose frame control for external callers
    public function processEvents():Void {
        handleEvents();
    }

    public function updateFrame(deltaTime:Float):Void {
        __input.update();
        
        if (currentState != null) {
            currentState.update(deltaTime);
        }
        
        __input.postUpdate();
    }

    public function swapBuffers():Void {
        SDL.swapWindow(__window.ptr);
    }

    private function preload():Void {
		resources.loadText("preload.txt").then(function(source:String) {
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
						case "tga":
							{
								files.push(__resources.loadTexture(path));
							}
						case "vert" | "frag" | "json":
							{
								files.push(__resources.loadText(path));
							}
						default:
							{
								throw 'Unsupported resource type: ' + ext + ' for file: ' + path;
							}
					}
				}
			}

			Promise.all(files).then(function(results:Array<Dynamic>) {
				__log.info(LogCategory.APP, "Successfully preloaded " + results.length + " assets");
			}).onError(function(error:String) {
				__log.error(LogCategory.APP, "Failed to preload some assets: " + error);
			});

		}).onError(function(error:String) {
			__log.error(LogCategory.APP, "Failed to load preload.txt: " + error);
		});
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

    public function get_renderer():Renderer {
        return __renderer;
    }
}