import { Engine } from '../common/engine.js';
import * as EngineConst from '../common/engine_const.js';
import { XmlRenderer } from './xml_renderer.js';
export class SsmlRenderer extends XmlRenderer {
    finalize(str) {
        return ('<?xml version="1.0"?><speak version="1.1"' +
            ' xmlns="http://www.w3.org/2001/10/synthesis"' +
            ` xml:lang="${Engine.getInstance().locale}">` +
            '<prosody rate="' +
            Engine.getInstance().getRate() +
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
            const id = Engine.getInstance().automark
                ? span.attributes['id']
                : Engine.getInstance().mark
                    ? span.attributes['extid']
                    : '';
            if (id &&
                id !== lastMark &&
                !(SsmlRenderer.MARK_ONCE && SsmlRenderer.MARKS[id])) {
                result.push(kind ? `<mark name="${id}" kind="${kind}"/>` : `<mark name="${id}"/>`);
                lastMark = id;
                SsmlRenderer.MARKS[id] = true;
            }
            if (Engine.getInstance().character &&
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
SsmlRenderer.MARK_ONCE = false;
SsmlRenderer.MARK_KIND = true;
SsmlRenderer.CHARACTER_ATTR = 'character';
SsmlRenderer.MARKS = {};
