import { CssHighlighter } from './css_highlighter.js';
export class ChtmlHighlighter extends CssHighlighter {
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
