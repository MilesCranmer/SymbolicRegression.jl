"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.setSeparator = setSeparator;
exports.getSeparator = getSeparator;
exports.markup = markup;
exports.merge = merge;
exports.finalize = finalize;
exports.error = error;
exports.registerRenderer = registerRenderer;
exports.isXml = isXml;
const engine_js_1 = require("../common/engine.js");
const EngineConst = require("../common/engine_const.js");
const acss_renderer_js_1 = require("./acss_renderer.js");
const layout_renderer_js_1 = require("./layout_renderer.js");
const punctuation_renderer_js_1 = require("./punctuation_renderer.js");
const sable_renderer_js_1 = require("./sable_renderer.js");
const span_js_1 = require("./span.js");
const ssml_renderer_js_1 = require("./ssml_renderer.js");
const string_renderer_js_1 = require("./string_renderer.js");
const xml_renderer_js_1 = require("./xml_renderer.js");
const xmlInstance = new ssml_renderer_js_1.SsmlRenderer();
const renderers = new Map([
    [EngineConst.Markup.NONE, new string_renderer_js_1.StringRenderer()],
    [EngineConst.Markup.COUNTING, new string_renderer_js_1.CountingRenderer()],
    [EngineConst.Markup.PUNCTUATION, new punctuation_renderer_js_1.PunctuationRenderer()],
    [EngineConst.Markup.LAYOUT, new layout_renderer_js_1.LayoutRenderer()],
    [EngineConst.Markup.ACSS, new acss_renderer_js_1.AcssRenderer()],
    [EngineConst.Markup.SABLE, new sable_renderer_js_1.SableRenderer()],
    [EngineConst.Markup.VOICEXML, xmlInstance],
    [EngineConst.Markup.SSML, xmlInstance]
]);
function setSeparator(sep) {
    const renderer = renderers.get(engine_js_1.Engine.getInstance().markup);
    if (renderer) {
        renderer.separator = sep;
    }
}
function getSeparator() {
    const renderer = renderers.get(engine_js_1.Engine.getInstance().markup);
    return renderer ? renderer.separator : '';
}
function markup(descrs) {
    const renderer = renderers.get(engine_js_1.Engine.getInstance().markup);
    if (!renderer) {
        return '';
    }
    return renderer.markup(descrs);
}
function merge(strs) {
    const span = strs.map((s) => {
        return typeof s === 'string' ? span_js_1.Span.stringEmpty(s) : s;
    });
    const renderer = renderers.get(engine_js_1.Engine.getInstance().markup);
    if (!renderer) {
        return strs.join();
    }
    return renderer.merge(span);
}
function finalize(str) {
    const renderer = renderers.get(engine_js_1.Engine.getInstance().markup);
    if (!renderer) {
        return str;
    }
    return renderer.finalize(str);
}
function error(key) {
    const renderer = renderers.get(engine_js_1.Engine.getInstance().markup);
    if (!renderer) {
        return '';
    }
    return renderer.error(key);
}
function registerRenderer(type, renderer) {
    renderers.set(type, renderer);
}
function isXml() {
    return renderers.get(engine_js_1.Engine.getInstance().markup) instanceof xml_renderer_js_1.XmlRenderer;
}
