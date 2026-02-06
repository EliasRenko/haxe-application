package;

import states.EditorState;

/**
 * Editor class - DLL entry point and API for C# integration
 * Combines the main DLL initialization and export API in one place
 */

// Inject C exports at header level (global scope)
@:headerCode('
extern "C" {
    __declspec(dllexport) const char* HxcppInit();
    __declspec(dllexport) void HxcppThreadAttach();
    __declspec(dllexport) void HxcppThreadDetach();
    __declspec(dllexport) void HxcppGarbageCollect(bool major);
    __declspec(dllexport) void EngineTestConsole();
    
    __declspec(dllexport) int EngineInit();
    __declspec(dllexport) void EngineUpdate(float deltaTime);
    __declspec(dllexport) void EngineRender();
    __declspec(dllexport) void EngineSwapBuffers();
    __declspec(dllexport) void EngineShutdown();
    __declspec(dllexport) void EngineRelease();
    __declspec(dllexport) void EngineLoadState(int stateIndex);
    __declspec(dllexport) int EngineIsRunning();
    __declspec(dllexport) int EngineGetWindowWidth();
    __declspec(dllexport) int EngineGetWindowHeight();
    __declspec(dllexport) void EngineSetWindowSize(int width, int height);
    __declspec(dllexport) void* EngineGetWindowHandle();
    __declspec(dllexport) void EngineSetWindowPosition(int x, int y);
    __declspec(dllexport) void EngineSetWindowSizeAndBorderless(int width, int height);
}
')

// Implement the C exports
@:cppFileCode('
#include <hx/Thread.h>
#include <windows.h>
#include <io.h>
#include <fcntl.h>
#include <stdio.h>

static bool hxcpp_initialized = false;
static hx::AutoGCFreeZone *mainZone = NULL;
static bool console_redirected = false;

void RedirectConsole() {
    if (console_redirected) return;
    
    // Allocate console
    if (!AllocConsole()) {
        // Console might already exist, try to attach
        if (!AttachConsole(ATTACH_PARENT_PROCESS)) {
            return;
        }
    }
    
    // Redirect stdout
    FILE* fpStdout = nullptr;
    freopen_s(&fpStdout, "CONOUT$", "w", stdout);
    
    // Redirect stderr  
    FILE* fpStderr = nullptr;
    freopen_s(&fpStderr, "CONOUT$", "w", stderr);
    
    // Redirect stdin
    FILE* fpStdin = nullptr;
    freopen_s(&fpStdin, "CONIN$", "r", stdin);
    
    // Disable buffering
    setvbuf(stdout, NULL, _IONBF, 0);
    setvbuf(stderr, NULL, _IONBF, 0);
    
    console_redirected = true;
    
    printf("========================================\\n");
    printf("DLL Console Initialized\\n");
    printf("========================================\\n");
    fflush(stdout);
}

// Custom trace function that writes directly to console
void EngineTrace(const char* msg) {
    if (!console_redirected) RedirectConsole();
    printf("[HAXE] %s\\n", msg);
    fflush(stdout);
}

extern "C" {
    // Test function to verify console output
    __declspec(dllexport) void EngineTestConsole() {
        RedirectConsole();
        printf("TEST: Console is working!\\n");
        fflush(stdout);
        EngineTrace("TEST: EngineTrace is working!");
    }
    
    // Haxe runtime initialization
    __declspec(dllexport) const char* HxcppInit() {
        if (hxcpp_initialized) {
            return NULL;  // Already initialized
        }
        
        // Redirect console first
        RedirectConsole();
        
        const char* err = hx::Init();
        if (err == NULL) {
            hxcpp_initialized = true;
            printf("Haxe runtime initialized\\n");
        } else {
            printf("Haxe init error: %s\\n", err);
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
        return ::Editor_obj::init();
    }
    
    __declspec(dllexport) void EngineUpdate(float deltaTime) {
        ::Editor_obj::updateFrame(deltaTime);
    }
    
    __declspec(dllexport) void EngineRender() {
        ::Editor_obj::render();
    }
    
    __declspec(dllexport) void EngineSwapBuffers() {
        ::Editor_obj::swapBuffers();
    }
    
    __declspec(dllexport) void EngineShutdown() {
        ::Editor_obj::engineShutdown();
    }
    
    __declspec(dllexport) void EngineRelease() {
        ::Editor_obj::release();
    }
    
    __declspec(dllexport) void EngineLoadState(int stateIndex) {
        ::Editor_obj::loadState(stateIndex);
    }
    
    __declspec(dllexport) int EngineIsRunning() {
        return ::Editor_obj::engineIsRunning();
    }
    
    __declspec(dllexport) int EngineGetWindowWidth() {
        return ::Editor_obj::engineGetWindowWidth();
    }
    
    __declspec(dllexport) int EngineGetWindowHeight() {
        return ::Editor_obj::engineGetWindowHeight();
    }
    
    __declspec(dllexport) void EngineSetWindowSize(int width, int height) {
        ::Editor_obj::engineSetWindowSize(width, height);
    }
    
    __declspec(dllexport) void* EngineGetWindowHandle() {
        return ::Editor_obj::getWindowHandle();
    }
    
    __declspec(dllexport) void EngineSetWindowPosition(int x, int y) {
        ::Editor_obj::setWindowPosition(x, y);
    }
    
    __declspec(dllexport) void EngineSetWindowSizeAndBorderless(int width, int height) {
        ::Editor_obj::engineSetWindowSizeAndBorderless(width, height);
    }
}
')

class Editor {
    
    // Store app instance
    private static var app:App = null;
    private static var initialized:Bool = false;
    
    /**
     * DLL Main - called when DLL mode is active
     */
    public static function main():Void {
        trace("Haxe Engine DLL loaded - ready for API calls");
        trace("Available exports: EngineInit, EngineUpdate, EngineRender, etc.");
    }
    
    // Custom log function that uses printf directly
    private static function log(msg:String):Void {
        untyped __cpp__("EngineTrace({0})", msg);
    }
    
    /**
     * Initialize the engine
     * @return 1 on success, 0 on failure
     */
    @:keep
    public static function init():Int {
        if (initialized) {
            log("Engine already initialized");
            return 1;
        }
        
        try {
            log("Editor: Initializing engine...");
            app = new App();
            if (!app.init()) {
                log("Editor: App.init() failed");
                return 0;
            }
            
            // Load the editor state by default
            app.addState(new EditorState(app));
            log("Editor: EditorState loaded");
            
            initialized = true;
            log("Editor: Engine initialized successfully");
            return 1;
        } catch (e:Dynamic) {
            log("Editor: Init error: " + e);
            return 0;
        }
    }
    
    /**
     * Run one frame update
     * @param deltaTime Time since last frame in seconds
     */
    @:keep
    public static function updateFrame(deltaTime:Float):Void {
        if (app == null || !initialized) {
            log("Editor: Cannot update - engine not initialized");
            return;
        }
        
        try {
            // Process events and update frame
            app.processEvents();
            app.updateFrame(deltaTime);
        } catch (e:Dynamic) {
            log("Editor: Update error: " + e);
        }
    }
    
    /**
     * Render one frame
     */
    @:keep
    public static function render():Void {
        if (app == null || !initialized) {
            log("Editor: Cannot render - engine not initialized");
            return;
        }
        
        try {
            app.renderFrame();
        } catch (e:Dynamic) {
            log("Editor: Render error: " + e);
            #if cpp
            var stack = haxe.CallStack.exceptionStack();
            log("Stack trace:");
            for (item in stack) {
                log("  " + haxe.CallStack.toString([item]));
            }
            #end
        }
    }
    
    /**
     * Swap window buffers (present frame)
     */
    @:keep
    public static function swapBuffers():Void {
        if (app != null && initialized) {
            app.swapBuffers();
        }
    }
    
    /**
     * Shutdown the engine
     */
    @:keep
    public static function engineShutdown():Void {
        log("Editor: Shutting down engine...");
        if (app != null) {
            app.release();
            app = null;
            initialized = false;
        }
    }
    
    /**
     * Release/cleanup engine resources
     */
    @:keep
    public static function release():Void {
        log("Editor: Releasing engine resources...");
        if (app != null) {
            app.release();
            log("Editor: Engine resources released");
            app = null;
            initialized = false;
        }
    }
    
    /**
     * Load a game state by ID
     * @param stateId State identifier
     * @return 1 on success, 0 on failure
     */
    @:keep
    public static function loadState(stateId:Int):Int {
        if (app == null || !initialized) {
            log("Editor: Engine not initialized");
            return 0;
        }
        
        try {
            log("Editor: Loading state " + stateId);
            switch (stateId) {
                case 0: 
                    app.addState(new EditorState(app));
                    log("Editor: EditorState loaded");
                default: 
                    log("Editor: Unknown state ID: " + stateId);
                    return 0;
            }
            return 1;
        } catch (e:Dynamic) {
            log("Editor: LoadState error: " + e);
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
            log("Editor: SetWindowSize not yet implemented");
        }
    }
    
    /**
     * Get native window handle (HWND on Windows)
     * Returns void* which can be cast to IntPtr in C#
     */
    @:keep
    public static function getWindowHandle():cpp.RawPointer<cpp.Void> {
        if (app != null && initialized && app.window != null) {
            return untyped __cpp__("SDL_GetPointerProperty(SDL_GetWindowProperties({0}), SDL_PROP_WINDOW_WIN32_HWND_POINTER, NULL)", app.window.ptr);
        }
        return null;
    }
    
    /**
     * Set window position (screen coordinates)
     */
    @:keep
    public static function setWindowPosition(x:Int, y:Int):Void {
        if (app != null && initialized && app.window != null) {
            app.window.setPosition(x, y);
        }
    }
    
    /**
     * Set window size and make it borderless for embedding
     */
    @:keep
    public static function engineSetWindowSizeAndBorderless(width:Int, height:Int):Void {
        if (app != null && initialized && app.window != null) {
            //app.window.setSize(width, height);
            //app.window.setBorderless(true);
        }
    }
}
