import { ChtmlHighlighter } from './chtml_highlighter.js';
import { ColorPicker } from './color_picker.js';
import { CssHighlighter } from './css_highlighter.js';
import { HtmlHighlighter } from './html_highlighter.js';
import { MmlCssHighlighter } from './mml_css_highlighter.js';
import { MmlHighlighter } from './mml_highlighter.js';
import { SvgHighlighter } from './svg_highlighter.js';
import { SvgV3Highlighter } from './svg_v3_highlighter.js';
export function highlighter(back, fore, rendererInfo) {
    const colorPicker = new ColorPicker(back, fore);
    const renderer = rendererInfo.renderer === 'NativeMML' && rendererInfo.browser === 'Safari'
        ? 'MML-CSS'
        : rendererInfo.renderer === 'SVG' && rendererInfo.browser === 'v3'
            ? 'SVG-V3'
            : rendererInfo.renderer;
    const highlighter = new (highlighterMapping[renderer] ||
        highlighterMapping['NativeMML'])();
    highlighter.setColor(colorPicker);
    return highlighter;
}
export function update(back, fore, highlighter) {
    const colorPicker = new ColorPicker(back, fore);
    highlighter.setColor(colorPicker);
}
export function addEvents(node, events, rendererInfo) {
    const highlight = highlighterMapping[rendererInfo.renderer];
    if (highlight) {
        new highlight().addEvents(node, events);
    }
}
const highlighterMapping = {
    SVG: SvgHighlighter,
    'SVG-V3': SvgV3Highlighter,
    NativeMML: MmlHighlighter,
    'HTML-CSS': HtmlHighlighter,
    'MML-CSS': MmlCssHighlighter,
    CommonHTML: CssHighlighter,
    CHTML: ChtmlHighlighter
};
