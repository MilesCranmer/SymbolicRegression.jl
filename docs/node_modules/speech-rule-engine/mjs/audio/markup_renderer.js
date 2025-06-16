import * as EngineConst from '../common/engine_const.js';
import { AbstractAudioRenderer } from './abstract_audio_renderer.js';
export class MarkupRenderer extends AbstractAudioRenderer {
    constructor() {
        super(...arguments);
        this.ignoreElements = [EngineConst.personalityProps.LAYOUT];
        this.scaleFunction = null;
    }
    setScaleFunction(a, b, c, d, decimals = 0) {
        this.scaleFunction = (x) => {
            const delta = (x - a) / (b - a);
            const num = c * (1 - delta) + d * delta;
            return +(Math.round((num + 'e+' + decimals)) +
                'e-' +
                decimals);
        };
    }
    applyScaleFunction(value) {
        return this.scaleFunction ? this.scaleFunction(value) : value;
    }
    ignoreElement(key) {
        return this.ignoreElements.indexOf(key) !== -1;
    }
}
