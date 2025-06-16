"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ChtmlHighlighter = void 0;
const css_highlighter_js_1 = require("./css_highlighter.js");
class ChtmlHighlighter extends css_highlighter_js_1.CssHighlighter {
    constructor() {
        super();
    }
    isMactionNode(node) {
        var _a;
        return ((_a = node.tagName) === null || _a === void 0 ? void 0 : _a.toUpperCase()) === this.mactionName.toUpperCase();
    }
    getMactionNodes(node) {
        return Array.from(node.getElementsByTagName(this.mactionName));
    }
}
exports.ChtmlHighlighter = ChtmlHighlighter;
