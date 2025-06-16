import * as EngineConst from '../common/engine_const.js';
import * as EventUtil from '../common/event_util.js';
import * as AudioUtil from './audio_util.js';
import { MarkupRenderer } from './markup_renderer.js';
export class AcssRenderer extends MarkupRenderer {
    markup(descrs) {
        this.setScaleFunction(-2, 2, 0, 10, 0);
        const markup = AudioUtil.personalityMarkup(descrs);
        const result = [];
        const currentPers = { open: [] };
        let pause = null;
        let isString = false;
        for (let i = 0, descr; (descr = markup[i]); i++) {
            if (AudioUtil.isMarkupElement(descr)) {
                AudioUtil.mergeMarkup(currentPers, descr);
                continue;
            }
            if (AudioUtil.isPauseElement(descr)) {
                if (isString) {
                    pause = AudioUtil.mergePause(pause, descr, Math.max);
                }
                continue;
            }
            const str = '"' + this.merge(descr.span) + '"';
            isString = true;
            if (pause) {
                result.push(this.pause(pause));
                pause = null;
            }
            const prosody = this.prosody_(currentPers);
            result.push(prosody ? '(text (' + prosody + ') ' + str + ')' : str);
        }
        return '(exp ' + result.join(' ') + ')';
    }
    error(key) {
        return '(error "' + EventUtil.Move.get(key) + '")';
    }
    prosodyElement(key, value) {
        value = this.applyScaleFunction(value);
        switch (key) {
            case EngineConst.personalityProps.RATE:
                return '(richness . ' + value + ')';
            case EngineConst.personalityProps.PITCH:
                return '(average-pitch . ' + value + ')';
            case EngineConst.personalityProps.VOLUME:
                return '(stress . ' + value + ')';
        }
        return '(value . ' + value + ')';
    }
    pause(pause) {
        return ('(pause . ' +
            this.pauseValue(pause[EngineConst.personalityProps.PAUSE]) +
            ')');
    }
    prosody_(pros) {
        const keys = pros.open;
        const result = [];
        for (let i = 0, key; (key = keys[i]); i++) {
            result.push(this.prosodyElement(key, pros[key]));
        }
        return result.join(' ');
    }
}
