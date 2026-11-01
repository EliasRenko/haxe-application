package gui;

enum abstract PropertyKind(Int) from Int to Int {
    var STRING = 0;
    var FLOAT = 1;
    var INT = 2;
    var BOOL = 3;
    var ENUM = 4;
}
