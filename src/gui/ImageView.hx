package gui;

import display.Image;
import data.TextureData;
import haxe.io.UInt8Array;
import gui.ImageHook;

/**
 * ImageView — displays an arbitrary RGBA/RGB image inside the GUI hierarchy.
 *
 * The image is rendered as a separate draw call, interleaved with the
 * UIBatch tile segments, so depth order relative to sibling controls is
 * fully preserved without any shader changes.
 *
 * Usage:
 *   var iv = new ImageView(128, 128, x, y);
 *   canvas.addControl(iv);
 *   iv.setPixels(rgbaBytes, 128, 128, 4);  // upload once (or on change)
 *
 * Requirements:
 *   The "textured" ProgramInfo must be registered in the renderer before any
 *   ImageView is added to the canvas.  Register it once in State.init():
 *     renderer.createProgramInfo("textured", vertSrc, fragSrc);
 */
class ImageView extends Control {

    // ** Privates
    private var __hook:ImageHook;
    private var __displayImage:Image = null;
    private var __imgW:Int = 0;
    private var __imgH:Int = 0;

    public function new(width:Float, height:Float, x:Float, y:Float) {
        super(x, y);
        __width  = width;
        __height = height;
        __type   = 'imageview';
        __hook   = new ImageHook();
    }

    override function init():Void {
        super.init();
        ____canvas.registerImageHook(__hook);
    }

    override function release():Void {
        ____canvas.unregisterImageHook(__hook);
        super.release();
    }

    override function update():Void {
        // ImageView is non-interactive; no input handling needed.
    }

    /**
     * Upload raw pixel data and display it inside this control's bounds.
     *
     * Calling this more than once replaces the previous image.
     * When the width/height match the previous call a new GPU texture is still
     * allocated via uploadTexture(); for streaming updates prefer keeping the
     * same dimensions so only glTexSubImage2D would be needed (future work).
     *
     * @param data  Raw pixel bytes (row-major, top-to-bottom)
     * @param w     Image width in pixels
     * @param h     Image height in pixels
     * @param bpp   Bytes per pixel: 3 = RGB, 4 = RGBA
     */
    public function setPixels(data:UInt8Array, w:Int, h:Int, bpp:Int = 4):Void {
        var renderer = ____canvas.renderer;
        var texData  = new TextureData(data, bpp, w, h, bpp == 4);
        var texture  = renderer.uploadTexture(texData);

        if (__displayImage == null || w != __imgW || h != __imgH) {
            // First call or size change — create a new Image with the texture.
            // Image.new() initialises vertices to texture.width × texture.height,
            // which matches the uploaded dimensions exactly.
            __displayImage = new Image(renderer, texture);
            __imgW = w;
            __imgH = h;
        } else {
            // Same dimensions: just swap the GPU texture handle.
            __displayImage.setTexture(texture);
        }

        __hook.displayImage = __displayImage;

        // Apply current world position (offset from parent container).
        __setGraphicX();
        __setGraphicY();
    }

    // ── Graphic position ──────────────────────────────────────────────────────

    override function __setGraphicX():Void {
        if (__displayImage != null) __displayImage.x = ____offsetX + __x;
    }

    override function __setGraphicY():Void {
        if (__displayImage != null) __displayImage.y = ____offsetY + __y;
    }

    // ── Getters / setters ─────────────────────────────────────────────────────

    override function set_visible(value:Bool):Bool {
        if (__hook != null) __hook.visible = value;
        return super.set_visible(value);
    }
}
