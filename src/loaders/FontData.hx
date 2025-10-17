package loaders;

/**
 * Font character data
 */
typedef FontChar = {
    var id:Int;           // Character code
    var x:Int;            // X position in texture
    var y:Int;            // Y position in texture
    var width:Int;        // Character width
    var height:Int;       // Character height
    var xoffset:Int;      // X offset when drawing
    var yoffset:Int;      // Y offset when drawing
    var xadvance:Int;     // How much to advance X after drawing
}

/**
 * Font data loaded from BMFont JSON
 */
typedef FontData = {
    var name:String;          // Font name
    var size:Int;             // Font size
    var lineHeight:Int;       // Height of a line
    var base:Int;             // Base line
    var textureWidth:Int;     // Texture atlas width
    var textureHeight:Int;    // Texture atlas height
    var textureName:String;   // Texture file name
    var chars:Map<Int, FontChar>;  // Character data by character code
}
