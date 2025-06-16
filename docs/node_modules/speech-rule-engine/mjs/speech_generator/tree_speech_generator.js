import { Attribute } from '../enrich_mathml/enrich_attr.js';
import * as WalkerUtil from '../walker/walker_util.js';
import { AbstractSpeechGenerator } from './abstract_speech_generator.js';
import * as SpeechGeneratorUtil from './speech_generator_util.js';
export class TreeSpeechGenerator extends AbstractSpeechGenerator {
    getSpeech(node, xml, root = null) {
        if (this.getRebuilt()) {
            SpeechGeneratorUtil.connectMactions(node, xml, this.getRebuilt().xml);
        }
        const speech = this.generateSpeech(node, xml);
        const nodes = this.getRebuilt().nodeDict;
        for (const [key, snode] of Object.entries(nodes)) {
            const innerMml = WalkerUtil.getBySemanticId(xml, key);
            const innerNode = WalkerUtil.getBySemanticId(node, key) ||
                (root && WalkerUtil.getBySemanticId(root, key));
            if (!innerMml || !innerNode) {
                continue;
            }
            if (!this.modality || this.modality === Attribute.SPEECH) {
                SpeechGeneratorUtil.addSpeech(innerNode, snode, this.getRebuilt().xml);
            }
            else {
                SpeechGeneratorUtil.addModality(innerNode, snode, this.modality);
            }
            if (this.modality === Attribute.SPEECH) {
                SpeechGeneratorUtil.addPrefix(innerNode, snode);
            }
        }
        return speech;
    }
}
