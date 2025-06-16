import * as EnrichAttr from '../enrich_mathml/enrich_attr.js';
import { AxisMap } from '../rule_engine/dynamic_cstr.js';
import { RebuildStree } from '../walker/rebuild_stree.js';
import { SpeechGenerator } from './speech_generator.js';
export declare abstract class AbstractSpeechGenerator implements SpeechGenerator {
    modality: EnrichAttr.Attribute;
    private rebuilt_;
    private options_;
    abstract getSpeech(node: Element, xml: Element, root?: Element): string;
    getRebuilt(): RebuildStree;
    setRebuilt(rebuilt: RebuildStree): void;
    computeRebuilt(xml: Element, force?: boolean): RebuildStree;
    setOptions(options: AxisMap): void;
    setOption(key: string, value: string): void;
    getOptions(): {
        [key: string]: string;
    };
    generateSpeech(_node: Node, xml: Element): string;
    nextRules(): void;
    nextStyle(id: string): void;
    private nextStyle_;
    getLevel(depth: string): string;
    getActionable(actionable: number): string;
}
