package;

import App;
import states.EditorState;
import states.CollisionTestState;
#if dll
import Editor;
#end

class Main {
    public static function main() {
        
        #if dll
        // DLL mode - delegate to Editor class
        Editor.main();
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
