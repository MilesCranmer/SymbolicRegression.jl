import { AbstractHighlighter, Highlight } from './abstract_highlighter.js';
export declare class CssHighlighter extends AbstractHighlighter {
    constructor();
    highlightNode(node: HTMLElement): {
        node: HTMLElement;
        background: string;
        foreground: string;
    };
    unhighlightNode(info: Highlight): void;
}
