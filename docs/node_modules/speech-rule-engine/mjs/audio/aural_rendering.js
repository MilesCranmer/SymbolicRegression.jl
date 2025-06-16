import { Engine } from '../common/engine.js';
import * as EngineConst from '../common/engine_const.js';
import { AcssRenderer } from './acss_renderer.js';
import { LayoutRenderer } from './layout_renderer.js';
import { PunctuationRenderer } from './punctuation_renderer.js';
import { SableRenderer } from './sable_renderer.js';
import { Span } from './span.js';
import { SsmlRenderer } from './ssml_renderer.js';
import { CountingRenderer, StringRenderer } from './string_renderer.js';
import { XmlRenderer } from './xml_renderer.js';
const xmlInstance = new SsmlRenderer();
const renderers = new Map([
    [EngineConst.Markup.NONE, new StringRenderer()],
    [EngineConst.Markup.COUNTING, new CountingRenderer()],
    [EngineConst.Markup.PUNCTUATION, new PunctuationRenderer()],
    [EngineConst.Markup.LAYOUT, new LayoutRenderer()],
    [EngineConst.Markup.ACSS, new AcssRenderer()],
    [EngineConst.Markup.SABLE, new SableRenderer()],
    [EngineConst.Markup.VOICEXML, xmlInstance],
    [EngineConst.Markup.SSML, xmlInstance]
]);
export function setSeparator(sep) {
    const renderer = renderers.get(Engine.getInstance().markup);
    if (renderer) {
        renderer.separator = sep;
    }
}
export function getSeparator() {
    const renderer = renderers.get(Engine.getInstance().markup);
    return renderer ? renderer.separator : '';
}
export function markup(descrs) {
    const renderer = renderers.get(Engine.getInstance().markup);
    if (!renderer) {
        return '';
    }
    return renderer.markup(descrs);
}
export function merge(strs) {
    const span = strs.map((s) => {
        return typeof s === 'string' ? Span.stringEmpty(s) : s;
    });
    const renderer = renderers.get(Engine.getInstance().markup);
    if (!renderer) {
        return strs.join();
    }
    return renderer.merge(span);
}
export function finalize(str) {
    const renderer = renderers.get(Engine.getInstance().markup);
    if (!renderer) {
        return str;
    }
    return renderer.finalize(str);
}
export function error(key) {
    const renderer = renderers.get(Engine.getInstance().markup);
    if (!renderer) {
        return '';
    }
    return renderer.error(key);
}
export function registerRenderer(type, renderer) {
    renderers.set(type, renderer);
}
export function isXml() {
    return renderers.get(Engine.getInstance().markup) instanceof XmlRenderer;
}
