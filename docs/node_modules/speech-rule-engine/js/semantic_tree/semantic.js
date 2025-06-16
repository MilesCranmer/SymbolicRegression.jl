"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.xmlTree = xmlTree;
exports.getTree = getTree;
exports.getTreeFromString = getTreeFromString;
const DomUtil = require("../common/dom_util.js");
const semantic_tree_js_1 = require("./semantic_tree.js");
function xmlTree(mml) {
    return getTree(mml).xml();
}
function getTree(mml) {
    return new semantic_tree_js_1.SemanticTree(mml);
}
function getTreeFromString(expr) {
    const mml = DomUtil.parseInput(expr);
    return getTree(mml);
}
