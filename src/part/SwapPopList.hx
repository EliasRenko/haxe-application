package part;

/**
 * SwapPopList<T> - Fast, unordered list with O(1) add/remove (swap-and-pop)
 *
 * - add(item): O(1)
 * - removeAt(index): O(1), does not preserve order
 * - remove(item): O(n), does not preserve order
 * - iteration: fast, dense
 */
class SwapPopList<T> {
    public var items:Array<T>;
    public var length(get, never):Int;

    public function new(capacity:Int = 0) {
        items = capacity > 0 ? new Array<T>(capacity) : [];
    }

    public inline function add(item:T):Int {
        items.push(item);
        return items.length - 1;
    }

    public inline function removeAt(index:Int):T {
        var last = items.length - 1;
        var removed = items[index];
        if (index != last) items[index] = items[last];
        items.pop();
        return removed;
    }

    public function remove(item:T):Bool {
        var idx = items.indexOf(item);
        if (idx == -1) return false;
        removeAt(idx);
        return true;
    }

    public inline function get(index:Int):T {
        return items[index];
    }

    public inline function clear():Void {
        items.resize(0);
    }

    inline function get_length() return items.length;

    public inline function iterator() {
        return items.iterator();
    }
}
