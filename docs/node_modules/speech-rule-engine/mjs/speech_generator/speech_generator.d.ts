import { Attribute } from '../enrich_mathml/enrich_attr.js';
import { AxisMap } from '../rule_engine/dynamic_cstr.js';
import { RebuildStree } from '../walker/rebuild_stree.js';
export interface SpeechGenerator {
    modality: Attribute;
    getSpeech(node: Element, xml: Element, root?: Element): string;
    generateSpeech(node: Element, xml: Element): string;
    getRebuilt(): RebuildStree;
    setRebuilt(rebuilt: RebuildStree): void;
    computeRebuilt(xml: Element, force?: boolean): RebuildStree;
    setOptions(options: AxisMap): void;
    setOption(key: string, value: string): void;
    getOptions(): AxisMap;
    nextRules(): void;
    nextStyle(id: string): void;
    getActionable(actionable: number): string;
    getLevel(depth: string): string;
}
