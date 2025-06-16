import { Color } from './color_picker.js';
import { Highlighter } from './highlighter.js';
export declare function highlighter(back: Color, fore: Color, rendererInfo: {
    renderer: string;
    browser?: string;
}): Highlighter;
export declare function update(back: Color, fore: Color, highlighter: Highlighter): void;
export declare function addEvents(node: HTMLElement, events: {
    [key: string]: EventListener;
}, rendererInfo: {
    renderer: string;
    browser?: string;
}): void;
