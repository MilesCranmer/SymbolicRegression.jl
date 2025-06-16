import { AbstractHighlighter, Highlight } from './abstract_highlighter.js';
export declare class MmlHighlighter extends AbstractHighlighter {
    constructor();
    highlightNode(node: HTMLElement): {
        node: HTMLElement;
    };
    unhighlightNode(info: Highlight): void;
    colorString(): import("./color_picker.js").StringColor;
    getMactionNodes(node: HTMLElement): HTMLElement[];
    isMactionNode(node: HTMLElement): boolean;
}
