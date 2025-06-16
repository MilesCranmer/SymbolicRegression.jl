"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.highlighter = highlighter;
exports.update = update;
exports.addEvents = addEvents;
const chtml_highlighter_js_1 = require("./chtml_highlighter.js");
const color_picker_js_1 = require("./color_picker.js");
const css_highlighter_js_1 = require("./css_highlighter.js");
const html_highlighter_js_1 = require("./html_highlighter.js");
const mml_css_highlighter_js_1 = require("./mml_css_highlighter.js");
const mml_highlighter_js_1 = require("./mml_highlighter.js");
const svg_highlighter_js_1 = require("./svg_highlighter.js");
const svg_v3_highlighter_js_1 = require("./svg_v3_highlighter.js");
function highlighter(back, fore, rendererInfo) {
    const colorPicker = new color_picker_js_1.ColorPicker(back, fore);
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
function update(back, fore, highlighter) {
    const colorPicker = new color_picker_js_1.ColorPicker(back, fore);
    highlighter.setColor(colorPicker);
}
function addEvents(node, events, rendererInfo) {
    const highlight = highlighterMapping[rendererInfo.renderer];
    if (highlight) {
        new highlight().addEvents(node, events);
    }
}
const highlighterMapping = {
    SVG: svg_highlighter_js_1.SvgHighlighter,
    'SVG-V3': svg_v3_highlighter_js_1.SvgV3Highlighter,
    NativeMML: mml_highlighter_js_1.MmlHighlighter,
    'HTML-CSS': html_highlighter_js_1.HtmlHighlighter,
    'MML-CSS': mml_css_highlighter_js_1.MmlCssHighlighter,
    CommonHTML: css_highlighter_js_1.CssHighlighter,
    CHTML: chtml_highlighter_js_1.ChtmlHighlighter
};
