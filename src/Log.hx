package;

enum abstract LogPriority(Int) from Int to Int {
    var INVALID = -1;
    var TRACE = 0;
    var VERBOSE = 1;
    var DEBUG = 2;
    var INFO = 3;
    var WARN = 4;
    var ERROR = 5;
    var CRITICAL = 6;
}

enum abstract LogCategory(Int) from Int to Int {
    var APP = 0;          // SDL_LOG_CATEGORY_APPLICATION
    var ASSERT = 2;       // SDL_LOG_CATEGORY_ASSERT
    var SYSTEM = 3;       // SDL_LOG_CATEGORY_SYSTEM
    var AUDIO = 4;        // SDL_LOG_CATEGORY_AUDIO
    var VIDEO = 5;        // SDL_LOG_CATEGORY_VIDEO
    var RENDERER = 6;     // SDL_LOG_CATEGORY_RENDER
    var INPUT = 7;        // SDL_LOG_CATEGORY_INPUT
    var TEST = 8;         // SDL_LOG_CATEGORY_TEST
    var RUNTIME = 19;     // SDL_LOG_CATEGORY_CUSTOM
    var RESOURCES = 20;   // SDL_LOG_CATEGORY_CUSTOM + 1
}

private class __Log {
    
    // Publics
    public var active:Bool = true;
    public var logHistory(get, null):String;

    // Privates
    private var __app:App;
    private var __logHistory:String = "";
    
    public function new(app:App, ?debugMode:Bool = false) {
        __app = app;

        if (debugMode) {
            // Enable DEBUG priority for all categories
            enablePriorityForCategory(LogCategory.APP, LogPriority.DEBUG);
            enablePriorityForCategory(LogCategory.ASSERT, LogPriority.DEBUG);
            enablePriorityForCategory(LogCategory.SYSTEM, LogPriority.DEBUG);
            enablePriorityForCategory(LogCategory.AUDIO, LogPriority.DEBUG);
            enablePriorityForCategory(LogCategory.VIDEO, LogPriority.DEBUG);
            enablePriorityForCategory(LogCategory.RENDERER, LogPriority.DEBUG);
            enablePriorityForCategory(LogCategory.INPUT, LogPriority.DEBUG);
            enablePriorityForCategory(LogCategory.TEST, LogPriority.DEBUG);
            enablePriorityForCategory(LogCategory.RUNTIME, LogPriority.DEBUG);
            enablePriorityForCategory(LogCategory.RESOURCES, LogPriority.DEBUG);
        }
    }
    
    public function init():Void {
    }

    public function release():Void {
        __app.resetLogPriorities();
    }
    
    public function enablePriorityForCategory(category:Int, priority:LogPriority):Void {
        __app.setLogPriority(category, priority);
    }
    
    public function disablePriorityForCategory(category:Int):Void {
        __app.setLogPriority(-1, category);
    }
    
    public function trace(category:Int, message:String):Void {
        __app.logTrace(category, message);
        __logHistory += "[TRACE] [" + getCategoryName(category) + "] " + message + "\n";
    }

    public function verbose(category:Int, message:String):Void {
        __app.logVerbose(category, message);
        __logHistory += "[VERBOSE] [" + getCategoryName(category) + "] " + message + "\n";
    }
    
    public function debug(category:Int, message:String):Void {
        __app.logDebug(category, message);
        __logHistory += "[DEBUG] [" + getCategoryName(category) + "] " + message + "\n";
    }
    
    public function info(category:Int, message:String):Void {
        __app.logInfo(category, message);
        __logHistory += "[INFO] [" + getCategoryName(category) + "] " + message + "\n";
    }
    
    public function warn(category:Int, message:String):Void {
        __app.logWarn(category, message);
        __logHistory += "[WARN] [" + getCategoryName(category) + "] " + message + "\n";
    }
    
    public function error(category:Int, message:String):Void {
        __app.logError(category, message);
        __logHistory += "[ERROR] [" + getCategoryName(category) + "] " + message + "\n";
    }
    
    public function critical(category:Int, message:String):Void {
        __app.logCritical(category, message);
        __logHistory += "[CRITICAL] [" + getCategoryName(category) + "] " + message + "\n";
    }

    // Privates
    private function getCategoryName(category:Int):String {
        switch (category) {
            case LogCategory.APP: return "App";
            case LogCategory.ASSERT: return "Assert";
            case LogCategory.SYSTEM: return "System";
            case LogCategory.AUDIO: return "Audio";
            case LogCategory.VIDEO: return "Video";
            case LogCategory.RENDERER: return "Renderer";
            case LogCategory.INPUT: return "Input";
            case LogCategory.TEST: return "Test";
            case LogCategory.RUNTIME: return "Runtime";
            case LogCategory.RESOURCES: return "Resources";
            default: return "Unknown";
        }
    }

    // Getters and setters
	private function get_logHistory():String {
		return __logHistory;
	}
}

typedef Log = __Log;