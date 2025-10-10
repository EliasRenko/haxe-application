package events;

enum abstract ControlEventType(UInt) from UInt to UInt {

	var ALL = 0;
	
	var ADDED = 1;
	
    var REMOVED = 2;
    
    var INIT = 3;

    var LEFT_CLICK = 4;

    var RIGHT_CLICK = 5;

    var ON_MOUSE_ENTER = 6;

    var ON_MOUSE_LEAVE = 7;

    var ON_HOVER = 8;

    var ON_SCROLL = 9;

    var ON_DRAG_ENTER = 10;

    var ON_DRAG_LEAVE = 11;

    var ON_DRAG = 12;

    var ON_LOCATION_CHANGE = 13;

    var ON_SIZE_CHANGE = 14;

    var ON_PARENT_CHANGE = 15;

    var ON_VISIBILITY_CHANGE = 16;

    var ON_TAB_INDEX_CHANGE = 17;

    var ON_ITEM_CLICK = 18;

    var ON_FOLD_CLICK = 19;

    var ON_TEXT_INPUT = 20;

    var ON_FOCUS_GAIN = 21;

    var ON_FOCUS_LOST = 22;

    var ON_FILE_SELECT = 23;
}
	