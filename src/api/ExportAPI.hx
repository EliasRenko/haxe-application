package api;

import App;

/**
 * C API Export Layer for DLL
 * Exposes Haxe engine functions to C# via C calling convention
 * 
 * To use from C#:
 * [DllImport("Main-debug.dll", CallingConvention = CallingConvention.Cdecl)]
 * public static extern int EngineInit();
 */

// Inject C exports at header level (global scope)
@:headerCode('
extern "C" {
    __declspec(dllexport) const char* HxcppInit();
    __declspec(dllexport) void HxcppThreadAttach();
    __declspec(dllexport) void HxcppThreadDetach();
    __declspec(dllexport) void HxcppGarbageCollect(bool major);
    
    __declspec(dllexport) int EngineInit();
    __declspec(dllexport) void EngineUpdate(float deltaTime);
    __declspec(dllexport) void EngineRender();
    __declspec(dllexport) void EngineSwapBuffers();
    __declspec(dllexport) void EngineShutdown();
    __declspec(dllexport) void EngineLoadState(int stateIndex);
    __declspec(dllexport) int EngineIsRunning();
    __declspec(dllexport) int EngineGetWindowWidth();
    __declspec(dllexport) int EngineGetWindowHeight();
    __declspec(dllexport) void EngineSetWindowSize(int width, int height);
}
')

// Implement the C exports
@:cppFileCode('
#include <hx/Thread.h>

static bool hxcpp_initialized = false;
static hx::AutoGCFreeZone *mainZone = NULL;

extern "C" {
    // Haxe runtime initialization
    __declspec(dllexport) const char* HxcppInit() {
        if (hxcpp_initialized) {
            return NULL;  // Already initialized
        }
        const char* err = hx::Init();
        if (err == NULL) {
            hxcpp_initialized = true;
        }
        return err;  // Returns NULL on success, error message on failure
    }
    
    __declspec(dllexport) void HxcppThreadAttach() {
        hx::SetTopOfStack((int*)0, true);
    }
    
    __declspec(dllexport) void HxcppThreadDetach() {
        hx::SetTopOfStack((int*)0, false);
    }
    
    __declspec(dllexport) void HxcppGarbageCollect(bool major) {
        // Trigger garbage collection
        extern void __hxcpp_collect(bool inMajor);
        __hxcpp_collect(major);
    }
    
    // Engine API - these use NativeAttach scope guards
    __declspec(dllexport) int EngineInit() {
        // Ensure runtime is initialized first
        if (!hxcpp_initialized) {
            const char* err = hx::Init();
            if (err != NULL) return 0;
            hxcpp_initialized = true;
        }
        
        // Use NativeAttach to properly set up the thread
        hx::NativeAttach attach;
        return ::api::ExportAPI_obj::engineInit();
    }
    
    __declspec(dllexport) void EngineUpdate(float deltaTime) {
        hx::NativeAttach attach;
        ::api::ExportAPI_obj::engineUpdate(deltaTime);
    }
    
    __declspec(dllexport) void EngineRender() {
        hx::NativeAttach attach;
        ::api::ExportAPI_obj::engineRender();
    }
    
    __declspec(dllexport) void EngineSwapBuffers() {
        hx::NativeAttach attach;
        ::api::ExportAPI_obj::engineSwapBuffers();
    }
    
    __declspec(dllexport) void EngineShutdown() {
        hx::NativeAttach attach;
        ::api::ExportAPI_obj::engineShutdown();
    }
    
    __declspec(dllexport) void EngineLoadState(int stateIndex) {
        hx::NativeAttach attach;
        ::api::ExportAPI_obj::engineLoadState(stateIndex);
    }
    
    __declspec(dllexport) int EngineIsRunning() {
        hx::NativeAttach attach;
        return ::api::ExportAPI_obj::engineIsRunning();
    }
    
    __declspec(dllexport) int EngineGetWindowWidth() {
        hx::NativeAttach attach;
        return ::api::ExportAPI_obj::engineGetWindowWidth();
    }
    
    __declspec(dllexport) int EngineGetWindowHeight() {
        hx::NativeAttach attach;
        return ::api::ExportAPI_obj::engineGetWindowHeight();
    }
    
    __declspec(dllexport) void EngineSetWindowSize(int width, int height) {
        hx::NativeAttach attach;
        ::api::ExportAPI_obj::engineSetWindowSize(width, height);
    }
}
')

class ExportAPI {
    
    // Store app instance
    private static var app:App = null;
    private static var initialized:Bool = false;
    
    /**
     * Initialize the engine
     * @return 1 on success, 0 on failure
     */
    @:keep
    public static function engineInit():Int {
        if (initialized) {
            trace("Engine already initialized");
            return 1;
        }
        
        try {
            trace("ExportAPI: Initializing engine...");
            app = new App();
            if (!app.init()) {
                trace("ExportAPI: App.init() failed");
                return 0;
            }
            initialized = true;
            trace("ExportAPI: Engine initialized successfully");
            return 1;
        } catch (e:Dynamic) {
            trace("ExportAPI: Init error: " + e);
            return 0;
        }
    }
    
    /**
     * Run one frame update
     * @param deltaTime Time since last frame in seconds
     */
    @:keep
    public static function engineUpdate(deltaTime:Float):Void {
        if (app != null && initialized) {
            // Process events and update frame
            app.processEvents();
            app.updateFrame(deltaTime);
        }
    }
    
    /**
     * Render one frame
     */
    @:keep
    public static function engineRender():Void {
        if (app != null && initialized) {
            app.renderFrame();
        }
    }
    
    /**
     * Swap window buffers (present frame)
     */
    @:keep
    public static function engineSwapBuffers():Void {
        if (app != null && initialized) {
            app.swapBuffers();
        }
    }
    
    /**
     * Shutdown the engine
     */
    @:keep
    public static function engineShutdown():Void {
        trace("ExportAPI: Shutting down engine...");
        if (app != null) {
            app.release();
            app = null;
            initialized = false;
        }
    }
    
    /**
     * Load a game state by ID
     * @param stateId State identifier (0=CollisionTest, 1=UITest, etc.)
     * @return 1 on success, 0 on failure
     */
    @:keep
    public static function engineLoadState(stateId:Int):Int {
        if (app == null || !initialized) {
            trace("ExportAPI: Engine not initialized");
            return 0;
        }
        
        try {
            trace("ExportAPI: Loading state " + stateId);
            switch (stateId) {
                case 0: 
                    app.addState(new states.CollisionTestState(app));
                    trace("ExportAPI: CollisionTestState loaded");
                case 1: 
                    #if false // Disabled until UITestState is fixed
                    app.addState(new states.UITestState(app));
                    trace("ExportAPI: UITestState loaded");
                    #else
                    trace("ExportAPI: UITestState not available");
                    return 0;
                    #end
                default: 
                    trace("ExportAPI: Unknown state ID: " + stateId);
                    return 0;
            }
            return 1;
        } catch (e:Dynamic) {
            trace("ExportAPI: LoadState error: " + e);
            return 0;
        }
    }
    
    /**
     * Check if engine is running
     * @return 1 if running, 0 if stopped
     */
    @:keep
    public static function engineIsRunning():Int {
        if (app != null && initialized) {
            return app.active ? 1 : 0;
        }
        return 0;
    }
    
    /**
     * Get window width
     */
    @:keep
    public static function engineGetWindowWidth():Int {
        if (app != null && initialized) {
            return app.WINDOW_WIDTH;
        }
        return 0;
    }
    
    /**
     * Get window height
     */
    @:keep
    public static function engineGetWindowHeight():Int {
        if (app != null && initialized) {
            return app.WINDOW_HEIGHT;
        }
        return 0;
    }
    
    /**
     * Set window size
     */
    @:keep
    public static function engineSetWindowSize(width:Int, height:Int):Void {
        if (app != null && initialized) {
            // TODO: Implement window resize
            trace("ExportAPI: SetWindowSize not yet implemented");
        }
    }
    
    // Future API extensions can be added here:
    // - Input injection
    // - Camera control
    // - Entity manipulation
    // - Resource loading
    // - Debug visualization
}
