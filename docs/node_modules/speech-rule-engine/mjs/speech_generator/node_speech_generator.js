import * as WalkerUtil from '../walker/walker_util.js';
import { TreeSpeechGenerator } from './tree_speech_generator.js';
export class NodeSpeechGenerator extends TreeSpeechGenerator {
    getSpeech(node, _xml) {
        super.getSpeech(node, _xml);
        return WalkerUtil.getAttribute(node, this.modality);
    }
}
