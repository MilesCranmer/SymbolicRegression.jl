"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.MmlCssHighlighter = void 0;
const css_highlighter_js_1 = require("./css_highlighter.js");
class MmlCssHighlighter extends css_highlighter_js_1.CssHighlighter {
    constructor() {
        super();
        this.mactionName = 'maction';
    }
    getMactionNodes(node) {
        return Array.from(node.getElementsByTagName(this.mactionName));
    }
    isMactionNode(node) {
        return node.tagName === this.mactionName;
    }
}
exports.MmlCssHighlighter = MmlCssHighlighter;
