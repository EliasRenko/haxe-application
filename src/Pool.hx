package;

@:generic
class Pool<T> {

        /** The available items in the pool. */
    public var items : Array<T>;
        /** The create callback called if there are no items left in the pool */
    public var create_func : Void->T;
        /** The fixed size limit, or 0 if no size limit is observed */
    public var size_limit: Int;

        /** Create a new pool with an initial cache size,
            an optional fixed size limit,
            and create callbacks */
    public function new(initial_size:Int, fixed_size_limit:Int=0, create_callback:Void->T){

        items = [];
        size_limit = fixed_size_limit;

        create_func = create_callback;

        var make = initial_size;
        if(size_limit > 0) make = Std.int(Math.min(make, size_limit));
        for(i in 0 ... make) items.push(create_func());

    } //new

        /** Get the next available item from the pool.
            If there are no available items the function returns null. */
    public inline function get() : T {

        if(items.length > 0) return items.pop();
        if(size_limit > 0) return null;

        return create_func();

    } //get

       
    public inline function put(item:T) {

        if(size_limit > 0 && (items.length+1 > size_limit)) {
            throw "Pool; invalid usage; putting item in will exceed size_limit";
        }

        items.push(item);

    } //put

} //Pool