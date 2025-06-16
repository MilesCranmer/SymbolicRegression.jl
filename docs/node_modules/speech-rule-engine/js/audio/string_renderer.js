"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CountingRenderer = exports.StringRenderer = void 0;
const engine_js_1 = require("../common/engine.js");
const abstract_audio_renderer_js_1 = require("./abstract_audio_renderer.js");
const audio_util_js_1 = require("./audio_util.js");
class StringRenderer extends abstract_audio_renderer_js_1.AbstractAudioRenderer {
    markup(descrs) {
        let str = '';
        const markup = (0, audio_util_js_1.personalityMarkup)(descrs);
        const clean = markup.filter((x) => x.span);
        if (!clean.length) {
            return str;
        }
        const len = clean.length - 1;
        for (let i = 0, descr; (descr = clean[i]); i++) {
            if (descr.span) {
                str += this.merge(descr.span);
            }
            if (i >= len) {
                continue;
            }
            const join = descr.join;
            str += typeof join === 'undefined' ? this.separator : join;
        }
        return str;
    }
}
exports.StringRenderer = StringRenderer;
class CountingRenderer extends StringRenderer {
    finalize(str) {
        const output = super.finalize(str);
        const count = engine_js_1.Engine.getInstance().modality === 'braille' ? '⣿⠀⣿⠀⣿⠀⣿⠀⣿⠀' : '0123456789';
        let second = new Array(Math.trunc(output.length / 10) + 1).join(count);
        second += count.slice(0, output.length % 10);
        return output + '\n' + second;
    }
}
exports.CountingRenderer = CountingRenderer;
