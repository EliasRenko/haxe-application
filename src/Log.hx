package;

@:enum
abstract LogPriority(Int) from Int to Int {
    var INVALID = -1;
    var TRACE = 0;
    var VERBOSE = 1;
    var DEBUG = 2;
    var INFO = 3;
    var WARN = 4;
    var ERROR = 5;
    var CRITICAL = 6;
    var COUNT = 7;
}

private class __Log {
    
    // Publics
    public var active:Bool = true;

    // Privates
    private var __app:App;
    
    public static inline var CATEGORY_RUNTIME:Int = 1;
    public static inline var CATEGORY_RENDERER:Int = 2;
    public static inline var CATEGORY_APP:Int = 3;
    public static inline var CATEGORY_RESOURCES:Int = 4;
    public static inline var CATEGORY_ASSERT:Int = 5;
    public static inline var CATEGORY_AUDIO:Int = 6;
    public static inline var CATEGORY_INPUT:Int = 7;
    public static inline var CATEGORY_TEST:Int = 8;
    
    public function new(app:App, ?callback:Void->Void) {
        __app = app;
    }
    
    public function init():Void {
    
    }

    public function release():Void {
        __app.resetLogPriorities();
    }
    
    // TODO: Change priority param
    public function enableCategory(category:Int, priority:Int):Void {
        __app.setLogPriority(category, SDL_LOG_PRIORITY_TRACE);
    }
    
    public function disableCategory(category:Int):Void {
        __app.setLogPriority(category, SDL_LOG_PRIORITY_INVALID);
    }
    
    public function trace(category:Int, message:String):Void {
        SDL.logTrace(category, "[" + getCategoryName(category) + "] " + message);
    }

    public function verbose(category:Int, message:String):Void {
        SDL.logVerbose(category, "[" + getCategoryName(category) + "] " + message);
    }
    
    public function debug(category:Int, message:String):Void {
        SDL.logDebug(category, "[" + getCategoryName(category) + "] " + message);
    }
    
    public function info(category:Int, message:String):Void {
        SDL.logInfo(category, "[" + getCategoryName(category) + "] " + message);
    }
    
    public function warn(category:Int, message:String):Void {
        SDL.logWarn(category, "[" + getCategoryName(category) + "] " + message);
    }
    
    public function error(category:Int, message:String):Void {
        SDL.logError(category, "[" + getCategoryName(category) + "] " + message);
    }
    
    public function critical(category:Int, message:String):Void {
        SDL.logCritical(category, "[" + getCategoryName(category) + "] " + message);
    }
    
    private function getCategoryName(category:Int):String {
        switch (category) {
            case CATEGORY_RUNTIME: return "RUNTIME";
            case CATEGORY_RENDERER: return "RENDER";
            case CATEGORY_APP: return "APP";
            case CATEGORY_RESOURCES: return "RESOURCES";
            case CATEGORY_ASSERT: return "ASSERT";
            case CATEGORY_AUDIO: return "AUDIO";
            case CATEGORY_INPUT: return "INPUT";
            case CATEGORY_TEST: return "TEST";
            default: return "UNKNOWN";
        }
    }
}

typedef Log = __Log;