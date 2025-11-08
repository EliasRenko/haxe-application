package gui;

import gui.ListItem;
import events.ControlEventType;

class List<T:Control> extends Container<ListItem<T>> {

    public function new(width:Float, x:Float, y:Float) {
        
        super(width, 0, x, y);

        type = 'list';
    }

    override function init() {

        super.init();

        for (listItem in __controls) {

            listItem.y = height;

            height += listItem.height;
        }
    }

    public function addControl(control:T):Control {

        var _listItem:ListItem<T> = new ListItem(control, width, 0);

        _listItem.addListener(__onItemClickEvent, LEFT_CLICK);

        // **

        __addControl(_listItem);

        if (____canvas != null) {
            
            _listItem.y = height;

            height += _listItem.height;
		}

        return _listItem;
    }

    public function removeControl(control:T):Bool {

        for (listItem in __controls) {

            if (listItem.item == control) {

                __removeControl(listItem);

                height -= control.height;

                var _y:Float = 0;
        
                for (listItem in __controls) {
        
                    listItem.y = _y;
        
                    _y += listItem.height;
                }

                return true;
            }
        }

        return false;
    }

    public function removeControlAt(index:UInt):Bool {
        
        var i:Int = 0;

        for (listItem in __controls) {

            if (i == index) {

                __removeControl(listItem);

                height -= listItem.height;

                var _y:Float = 0;
        
                for (listItem in __controls) {
        
                    listItem.y = _y;
        
                    _y += listItem.height;
                }

                return true;
            }

            i ++;
        }

        return false;
    }

    public function onItemClick(control:Control):Void {
        
        dispatchEvent(control, ON_ITEM_CLICK);
    }

    private function __onItemClickEvent(control:Control, type:UInt):Void {

        onItemClick(control);
    }
}