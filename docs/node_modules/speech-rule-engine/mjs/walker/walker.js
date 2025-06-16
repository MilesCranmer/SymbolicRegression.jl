export var WalkerMoves;
(function (WalkerMoves) {
    WalkerMoves["UP"] = "up";
    WalkerMoves["DOWN"] = "down";
    WalkerMoves["LEFT"] = "left";
    WalkerMoves["RIGHT"] = "right";
    WalkerMoves["REPEAT"] = "repeat";
    WalkerMoves["DEPTH"] = "depth";
    WalkerMoves["ENTER"] = "enter";
    WalkerMoves["EXPAND"] = "expand";
    WalkerMoves["HOME"] = "home";
    WalkerMoves["SUMMARY"] = "summary";
    WalkerMoves["DETAIL"] = "detail";
    WalkerMoves["ROW"] = "row";
    WalkerMoves["CELL"] = "cell";
})(WalkerMoves || (WalkerMoves = {}));
export class WalkerState {
    static resetState(id) {
        delete WalkerState.STATE[id];
    }
    static setState(id, value) {
        WalkerState.STATE[id] = value;
    }
    static getState(id) {
        return WalkerState.STATE[id];
    }
}
WalkerState.STATE = {};
