import * as EngineConst from '../common/engine_const.js';
import { AbstractAudioRenderer } from './abstract_audio_renderer.js';
import * as AudioUtil from './audio_util.js';
export class PunctuationRenderer extends AbstractAudioRenderer {
    markup(descrs) {
        const markup = AudioUtil.personalityMarkup(descrs);
        let str = '';
        let pause = null;
        let span = false;
        for (let i = 0, descr; (descr = markup[i]); i++) {
            if (AudioUtil.isMarkupElement(descr)) {
                continue;
            }
            if (AudioUtil.isPauseElement(descr)) {
                pause = descr;
                continue;
            }
            if (pause) {
                str += this.pause(pause[EngineConst.personalityProps.PAUSE]);
                pause = null;
            }
            str += (span ? this.separator : '') + this.merge(descr.span);
            span = true;
        }
        return str;
    }
    pause(pause) {
        let newPause;
        if (typeof pause === 'number') {
            if (pause <= 250) {
                newPause = 'short';
            }
            else if (pause <= 500) {
                newPause = 'medium';
            }
            else {
                newPause = 'long';
            }
        }
        else {
            newPause = pause;
        }
        return PunctuationRenderer.PAUSE_PUNCTUATION.get(newPause) || '';
    }
}
PunctuationRenderer.PAUSE_PUNCTUATION = new Map([
    ['short', ','],
    ['medium', ';'],
    ['long', '.']
]);
