"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SsmlRenderer = void 0;
const engine_js_1 = require("../common/engine.js");
const EngineConst = require("../common/engine_const.js");
const xml_renderer_js_1 = require("./xml_renderer.js");
class SsmlRenderer extends xml_renderer_js_1.XmlRenderer {
    finalize(str) {
        return ('<?xml version="1.0"?><speak version="1.1"' +
            ' xmlns="http://www.w3.org/2001/10/synthesis"' +
            ` xml:lang="${engine_js_1.Engine.getInstance().locale}">` +
            '<prosody rate="' +
            engine_js_1.Engine.getInstance().getRate() +
            '%">' +
            this.separator +
            str +
            this.separator +
            '</prosody></speak>');
    }
    pause(pause) {
        return ('<break ' +
            'time="' +
            this.pauseValue(pause[EngineConst.personalityProps.PAUSE]) +
            'ms"/>');
    }
    prosodyElement(attr, value) {
        value = Math.floor(this.applyScaleFunction(value));
        const valueStr = value < 0 ? value.toString() : '+' + value.toString();
        return ('<prosody ' +
            attr.toLowerCase() +
            '="' +
            valueStr +
            (attr === EngineConst.personalityProps.VOLUME ? '>' : '%">'));
    }
    closeTag(_tag) {
        return '</prosody>';
    }
    markup(descrs) {
        SsmlRenderer.MARKS = {};
        return super.markup(descrs);
    }
    merge(spans) {
        const result = [];
        let lastMark = '';
        for (let i = 0; i < spans.length; i++) {
            const span = spans[i];
            if (this.isEmptySpan(span))
                continue;
            const kind = SsmlRenderer.MARK_KIND ? span.attributes['kind'] : '';
            const id = engine_js_1.Engine.getInstance().automark
                ? span.attributes['id']
                : engine_js_1.Engine.getInstance().mark
                    ? span.attributes['extid']
                    : '';
            if (id &&
                id !== lastMark &&
                !(SsmlRenderer.MARK_ONCE && SsmlRenderer.MARKS[id])) {
                result.push(kind ? `<mark name="${id}" kind="${kind}"/>` : `<mark name="${id}"/>`);
                lastMark = id;
                SsmlRenderer.MARKS[id] = true;
            }
            if (engine_js_1.Engine.getInstance().character &&
                span.speech.length === 1 &&
                span.speech.match(/[a-zA-Z]/)) {
                result.push('<say-as interpret-as="' +
                    SsmlRenderer.CHARACTER_ATTR +
                    '">' +
                    span.speech +
                    '</say-as>');
            }
            else {
                result.push(span.speech);
            }
        }
        return result.join(this.separator);
    }
    isEmptySpan(span) {
        const sep = span.attributes['separator'];
        return span.speech.match(/^\s*$/) && (!sep || sep.match(/^\s*$/));
    }
}
exports.SsmlRenderer = SsmlRenderer;
SsmlRenderer.MARK_ONCE = false;
SsmlRenderer.MARK_KIND = true;
SsmlRenderer.CHARACTER_ATTR = 'character';
SsmlRenderer.MARKS = {};
