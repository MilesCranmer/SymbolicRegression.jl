import { Engine } from '../common/engine.js';
import { AbstractAudioRenderer } from './abstract_audio_renderer.js';
import { personalityMarkup } from './audio_util.js';
export class StringRenderer extends AbstractAudioRenderer {
    markup(descrs) {
        let str = '';
        const markup = personalityMarkup(descrs);
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
export class CountingRenderer extends StringRenderer {
    finalize(str) {
        const output = super.finalize(str);
        const count = Engine.getInstance().modality === 'braille' ? '⣿⠀⣿⠀⣿⠀⣿⠀⣿⠀' : '0123456789';
        let second = new Array(Math.trunc(output.length / 10) + 1).join(count);
        second += count.slice(0, output.length % 10);
        return output + '\n' + second;
    }
}
