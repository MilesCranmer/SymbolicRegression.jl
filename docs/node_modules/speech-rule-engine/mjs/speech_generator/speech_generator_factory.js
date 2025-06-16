import { AdhocSpeechGenerator } from './adhoc_speech_generator.js';
import { ColorGenerator } from './color_generator.js';
import { DirectSpeechGenerator } from './direct_speech_generator.js';
import { DummySpeechGenerator } from './dummy_speech_generator.js';
import { NodeSpeechGenerator } from './node_speech_generator.js';
import { SummarySpeechGenerator } from './summary_speech_generator.js';
import { TreeSpeechGenerator } from './tree_speech_generator.js';
export function generator(type) {
    const constructor = generatorMapping[type] || generatorMapping.Direct;
    return constructor();
}
const generatorMapping = {
    Adhoc: () => new AdhocSpeechGenerator(),
    Color: () => new ColorGenerator(),
    Direct: () => new DirectSpeechGenerator(),
    Dummy: () => new DummySpeechGenerator(),
    Node: () => new NodeSpeechGenerator(),
    Summary: () => new SummarySpeechGenerator(),
    Tree: () => new TreeSpeechGenerator()
};
