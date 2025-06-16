"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.removeEmpty = removeEmpty;
exports.interleaveLists = interleaveLists;
exports.setdifference = setdifference;
function removeEmpty(strs) {
    return strs.filter((str) => str);
}
function interleaveLists(list1, list2) {
    const result = [];
    while (list1.length || list2.length) {
        if (list1.length) {
            result.push(list1.shift());
        }
        if (list2.length) {
            result.push(list2.shift());
        }
    }
    return result;
}
function setdifference(a, b) {
    if (!a) {
        return [];
    }
    if (!b) {
        return a;
    }
    return a.filter((x) => b.indexOf(x) < 0);
}
