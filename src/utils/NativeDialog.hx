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
  #include <string.h>
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

    /**
     * Show an Open File dialog that allows selecting multiple image files
     * (TGA, PNG, BMP).  Uses OFN_ALLOWMULTISELECT | OFN_EXPLORER so the
     * user can Ctrl-click or Shift-click any number of files.
     *
     * @return Array of absolute paths (empty if cancelled).
     */
    public static function openImageFiles():Array<String> {
        var packed:String = "";
        untyped __cpp__('
            #if defined(_WIN32)
            const int FBUF = 32768;
            static char szFile[32768];
            memset(szFile, 0, FBUF);
            const char filter[] = "Image Files" "\\0" "*.tga;*.png;*.bmp" "\\0" "All Files" "\\0" "*.*" "\\0";
            OPENFILENAMEA ofn = {};
            ofn.lStructSize  = sizeof(OPENFILENAMEA);
            ofn.hwndOwner    = NULL;
            ofn.lpstrFile    = szFile;
            ofn.nMaxFile     = FBUF;
            ofn.lpstrFilter  = filter;
            ofn.nFilterIndex = 1;
            ofn.lpstrTitle   = "Select Image Files";
            ofn.Flags        = OFN_PATHMUSTEXIST | OFN_FILEMUSTEXIST | OFN_NOCHANGEDIR
                             | OFN_ALLOWMULTISELECT | OFN_EXPLORER;
            if (GetOpenFileNameA(&ofn)) {
                static char result[65536];
                memset(result, 0, sizeof(result));
                const char FSEP = "||"[0];
                const char FBS  = "\\\\"[0];
                int rpos = 0;
                char* p  = szFile;
                char* pn = p + strlen(p) + 1;
                if (*pn == 0) {
                    int len = (int)strlen(szFile);
                    if (len < 65534) memcpy(result, szFile, len);
                } else {
                    int dirLen = (int)strlen(p);
                    char* fname = pn;
                    while (*fname != 0) {
                        int fLen = (int)strlen(fname);
                        if (rpos > 0 && rpos < 65533) result[rpos++] = FSEP;
                        if (rpos + dirLen + 1 + fLen < 65534) {
                            memcpy(result + rpos, p, dirLen); rpos += dirLen;
                            result[rpos++] = FBS;
                            memcpy(result + rpos, fname, fLen); rpos += fLen;
                        }
                        fname += fLen + 1;
                    }
                }
                {0} = ::String(result);
            }
            #endif
        ', packed);
        if (packed.length == 0) return [];
        return packed.split("|");
    }
}

#else

class NativeDialog {
    public static function openFontFile():Null<String> return null;
    public static function openImageFiles():Array<String> return [];
}

#end
