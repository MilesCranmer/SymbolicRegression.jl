import * as WalkerUtil from '../walker/walker_util.js';
import { AbstractSpeechGenerator } from './abstract_speech_generator.js';
export class DirectSpeechGenerator extends AbstractSpeechGenerator {
    getSpeech(node, _xml) {
        return WalkerUtil.getAttribute(node, this.modality);
    }
}
