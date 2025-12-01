package;

#if native

//import states.AtlasState;
import App;
import states.CollisionTestState;
//import states.UITestState;
//import states.TileBatchPerformanceTest;

class Main {
    public static function main() {
        
        var app = new App();
        if (!app.init()) {
            trace("Failed to initialize application");
            return;
        }

        app.addState(new CollisionTestState(app));
        //app.addState(new UITestState(app));
        app.run();
    }
}

#elseif web

class Main {

    public static function main() {
        trace("Running in web backend");
    }
}

#end
