package gui;

/**
 * Dialog - Modal popup window
 * Simple implementation that can be extended later with Window features
 * 
 * For now, Dialog is just a specialized Container
 * Future: Add title bar, close button, dragging, etc.
 */
class Dialog extends Container<Control> {

    /**
     * Create a new dialog
     * @param title Dialog title (currently unused, for future title bar)
     * @param width Dialog width
     * @param height Dialog height
     */
    public function new(title:String, width:Float, height:Float) {
        super(width, height, 0, 0);
        __type = 'dialog';
    }

    /**
     * Initialize dialog
     * Override to add title bar, background panel, etc.
     */
    override function init():Void {
        super.init();
        // TODO: Add dialog background panel
        // TODO: Add title bar
        // TODO: Add close button
    }
}
