package;

import Promise;
import loaders.TGALoader;
import data.TextureData;

typedef Resource = {
    var type:String;
    var data:Dynamic;
    var size:Int;
}

private class __Resources {
    // Publics
    public var count(get, null):Int;
    public var preDefinedPath(get, set):String;

    // Privates
    private var __resources:Map<String, Resource> = new Map<String, Resource>();
    private var __parent:App;
    private var __preDefinedPath:String;

    public function new(app:App, preDefinedPath:String = "res") {
        this.__parent = app;
        this.__preDefinedPath = preDefinedPath;
    }

    public function cached(name:String):Bool {
        if (__resources.exists(name)) {
            return true;
        }

        return false;
    }

    public function getText(name:String):String {
        if (__resources.exists(name)) {
            var _resource:Resource = __resources.get(name);
            if (_resource == null) {
                return null;
            }
            return cast(_resource.data, String);
        }

        throw "Resource not found: " + name;
    }

    public function getTexture(name:String):TextureData {
        if (__resources.exists(name)) {
            var _resource:Resource = __resources.get(name);
            if (_resource == null || _resource.type != 'texture') {
                return null;
            }
            return cast(_resource.data, TextureData);
        }
        
        throw "Resource not found: " + name;
    }

    public function loadText(path:String, relative:Bool = true, cache:Bool = true):Promise<String> {
        var fullPath = relative ? __preDefinedPath + "/" + path : path;
        return new Promise<String>((resolve, reject) -> {
            try {
                var bytes = __parent.loadBytes(fullPath);
                var data:String = bytes.toString();
                if (cache) __resources.set(path, {type: 'text', data: data, size: bytes.length});
                resolve(data);
            } catch (e:Dynamic) {
                reject("Failed to load text file: " + fullPath + " - " + e);
            }
        });
    }

    public function loadShader(vertexPath:String, fragmentPath:String, relative:Bool = true, cache:Bool = true):Promise<{vertex:String, fragment:String}> {
        var fullVertexPath = relative ? __preDefinedPath + "/" + vertexPath : vertexPath;
        var fullFragmentPath = relative ? __preDefinedPath + "/" + fragmentPath : fragmentPath;
        return new Promise<{vertex:String, fragment:String}>((resolve, reject) -> {
            try {
                var vertexBytes = __parent.loadBytes(fullVertexPath);
                var fragmentBytes = __parent.loadBytes(fullFragmentPath);
                var vertex = vertexBytes.toString();
                var fragment = fragmentBytes.toString();
                if (cache) {
                    __resources.set(vertexPath, {type: 'text', data: vertex, size: vertexBytes.length});
                    __resources.set(fragmentPath, {type: 'text', data: fragment, size: fragmentBytes.length});
                }
                resolve({vertex: vertex, fragment: fragment});
            } catch (e:Dynamic) {
                reject("Failed to load shader files: " + e);
            }
        });
    }

    public function loadTexture(path:String, relative:Bool = true, cache:Bool = true):Promise<TextureData> {
        var fullPath = relative ? __preDefinedPath + "/" + path : path;
        return new Promise<TextureData>((resolve, reject) -> {
            try {
                var bytes = __parent.loadBytes(fullPath);
                // Parse TGA
                var textureData = TGALoader.loadFromBytes(bytes, fullPath);
                if (cache) {
                    __resources.set(path, {type: 'texture', data: textureData, size: bytes.length});
                }
                resolve(textureData);
            } catch (e:Dynamic) {
                reject("Failed to load texture: " + e);
            }
        });
    }

    public function clear():Void {
        var count = 0;
        for (key in __resources.keys()) {
            var resource = __resources.get(key);
            if (resource != null) {
                count++;
                // Dispose texture data if it's a texture
                if (resource.type == 'texture') {
                    var textureData:TextureData = cast(resource.data, TextureData);
                    if (textureData != null) {
                        textureData.dispose();
                    }
                }
            }
        }

        __resources.clear();
    }
    
    public function release():Void {
        clear();
        __preDefinedPath = null;
    }

    public function remove(name:String, relative:Bool = true):Bool {
        var fullPath = relative ? __preDefinedPath + "/" + name : name;
        if (__resources.exists(fullPath)) {
            var resource = __resources.get(fullPath);
            if (resource != null) {
                // Dispose texture data if it's a texture
                if (resource.type == 'texture') {
                    var textureData:TextureData = cast(resource.data, TextureData);
                    if (textureData != null) {
                        textureData.dispose();
                    }
                }

                __resources.remove(fullPath);
                return true;
            }
        }
        return false;
    }

    // Getters/Setters
    public function get_count():Int {
        return Lambda.count(__resources);
    }

    public function get_preDefinedPath():String {
        return __preDefinedPath;
    }

    public function set_preDefinedPath(value:String):String {
        __preDefinedPath = value;
        return __preDefinedPath;
    }
}

typedef Resources = __Resources;