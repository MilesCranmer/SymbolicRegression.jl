import { AbstractHighlighter } from './abstract_highlighter.js';
export class CssHighlighter extends AbstractHighlighter {
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
