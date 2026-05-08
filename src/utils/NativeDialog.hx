package utils;

/**
 * NativeDialog — synchronous OS file picker.
 *
 * Desktop (hxcpp): blocks until the user picks a file or cancels.
 * Web: always returns null (no synchronous file picker available).
 */
#if !js

@:buildXml('
<target id="haxe">
  <lib name="comdlg32.lib" if="windows"/>
</target>
')
@:cppFileCode('
#if defined(_WIN32)
  #ifndef NOMINMAX
  #define NOMINMAX
  #endif
  #include <windows.h>
  #include <commdlg.h>
#endif
')
class NativeDialog {

    /**
     * Show an Open File dialog filtered to TrueType fonts.
     * @return Absolute path to the selected file, or null if cancelled.
     */
    public static function openFontFile():Null<String> {
        var path:String = "";
        untyped __cpp__('
            #if defined(_WIN32)
            OPENFILENAMEA ofn = {};
            char szFile[MAX_PATH] = {};
            const char filter[] = "TrueType Fonts" "\\0" "*.ttf;*.otf" "\\0" "All Files" "\\0" "*.*" "\\0";
            ofn.lStructSize  = sizeof(OPENFILENAMEA);
            ofn.hwndOwner    = NULL;
            ofn.lpstrFile    = szFile;
            ofn.nMaxFile     = MAX_PATH;
            ofn.lpstrFilter  = filter;
            ofn.nFilterIndex = 1;
            ofn.lpstrTitle   = "Select a TrueType Font";
            ofn.Flags        = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_NOCHANGEDIR;
            if (GetOpenFileNameA(&ofn)) {
                {0} = ::String(szFile);
            }
            #endif
        ', path);
        return path.length > 0 ? path : null;
    }
}

#else

class NativeDialog {
    public static function openFontFile():Null<String> return null;
}

#end
