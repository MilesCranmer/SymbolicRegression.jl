import { CssHighlighter } from './css_highlighter.js';
export class MmlCssHighlighter extends CssHighlighter {
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
