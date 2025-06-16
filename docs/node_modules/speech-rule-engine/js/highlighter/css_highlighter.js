"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CssHighlighter = void 0;
const abstract_highlighter_js_1 = require("./abstract_highlighter.js");
class CssHighlighter extends abstract_highlighter_js_1.AbstractHighlighter {
    constructor() {
        super();
        this.mactionName = 'mjx-maction';
    }
    highlightNode(node) {
        const info = {
            node: node,
            background: node.style.backgroundColor,
            foreground: node.style.color
        };
        if (!this.isHighlighted(node)) {
            const color = this.colorString();
            node.style.backgroundColor = color.background;
            node.style.color = color.foreground;
        }
        return info;
    }
    unhighlightNode(info) {
        info.node.style.backgroundColor = info.background;
        info.node.style.color = info.foreground;
    }
}
exports.CssHighlighter = CssHighlighter;
