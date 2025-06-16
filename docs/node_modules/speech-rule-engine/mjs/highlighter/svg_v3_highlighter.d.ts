import { Highlight } from './abstract_highlighter.js';
import { SvgHighlighter } from './svg_highlighter.js';
export declare class SvgV3Highlighter extends SvgHighlighter {
    constructor();
    highlightNode(node: HTMLElement): Highlight;
    unhighlightNode(info: Highlight): void;
    isMactionNode(node: HTMLElement): boolean;
    getMactionNodes(node: HTMLElement): HTMLElement[];
}
