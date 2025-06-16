import { CssHighlighter } from './css_highlighter.js';
export declare class ChtmlHighlighter extends CssHighlighter {
    constructor();
    isMactionNode(node: HTMLElement): boolean;
    getMactionNodes(node: HTMLElement): HTMLElement[];
}
