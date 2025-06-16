"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AbstractAudioRenderer = void 0;
const engine_js_1 = require("../common/engine.js");
class AbstractAudioRenderer {
    constructor() {
        this.separator_ = ' ';
    }
    set separator(sep) {
        this.separator_ = sep;
    }
    get separator() {
        return engine_js_1.Engine.getInstance().modality === 'braille' ? '' : this.separator_;
    }
    error(_key) {
        return null;
    }
    merge(spans) {
        let str = '';
        const len = spans.length - 1;
        for (let i = 0, span; (span = spans[i]); i++) {
            str += span.speech;
            if (i < len) {
                const sep = span.attributes['separator'];
                str += sep !== undefined ? sep : this.separator;
            }
        }
        return str;
    }
    finalize(str) {
        return str;
    }
    pauseValue(value) {
        let numeric;
        switch (value) {
            case 'long':
                numeric = 750;
                break;
            case 'medium':
                numeric = 500;
                break;
            case 'short':
                numeric = 250;
                break;
            default:
                numeric = parseInt(value, 10);
        }
        return Math.floor((numeric * engine_js_1.Engine.getInstance().getRate()) / 100);
    }
}
exports.AbstractAudioRenderer = AbstractAudioRenderer;
