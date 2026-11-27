package;

import states.GUITestState;
import states.MenuState;
import states.PhysicsState;
import display.ScanlineScreenPass;
import display.GrayscaleScreenPass;
import display.DepthVisualizationScreenPass;
#if dll
import Editor;
#end

class Main {
    public static function main() {
        var app = new App();
        app.init();

        var renderer = app.renderer;
        var size = app.window.getWindowSizeInPixels();
        try {
            app.postProcessing.addPass(new ScanlineScreenPass(renderer, size.width, size.height));
            app.postProcessing.addPass(new GrayscaleScreenPass(renderer, size.width, size.height));
            app.postProcessing.addPass(new DepthVisualizationScreenPass(renderer, size.width, size.height));
        } catch (error:Dynamic) {
            app.postProcessing.release();
            throw error;
        }

        app.addState(new MenuState(app));
        app.addState(new GUITestState(app));
        app.addState(new PhysicsState(app));
        #if cpp
        app.addState(new states.FontEditor(app));
        app.addState(new states.PackerState(app));
        #end
        app.run();
    }
}
