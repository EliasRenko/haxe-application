package;

import App;
import states.CollisionTestState;
#if dll
import api.ExportAPI;
#end

class Main {
    public static function main() {
        
        #if dll
        // DLL mode - do nothing in main, wait for C# to call exports
        trace("Haxe Engine DLL loaded - ready for API calls");
        trace("Available exports: EngineInit, EngineUpdate, EngineRender, etc.");
        // Note: ExportAPI class must be referenced to ensure it's compiled
        var _ = ExportAPI.engineIsRunning;
        #else
        // Normal executable mode
        var app = new App();
        if (!app.init()) {
            trace("Failed to initialize application");
            return;
        }

        app.addState(new CollisionTestState(app));
        app.run();
        #end
    }
}
