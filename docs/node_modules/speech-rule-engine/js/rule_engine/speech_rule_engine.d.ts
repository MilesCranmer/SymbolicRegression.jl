import { AuditoryDescription } from '../audio/auditory_description.js';
import { BaseRuleStore } from './base_rule_store.js';
import { RulesJson } from './base_rule_store.js';
import { DynamicCstr } from './dynamic_cstr.js';
import { State as GrammarState } from './grammar.js';
import { SpeechRule } from './speech_rule.js';
import { SpeechRuleContext } from './speech_rule_context.js';
import { Trie } from '../indexing/trie.js';
export declare class SpeechRuleEngine {
    private static instance;
    trie: Trie;
    private evaluators_;
    static getInstance(): SpeechRuleEngine;
    static debugSpeechRule(rule: SpeechRule, node: Element): void;
    static debugNamedSpeechRule(name: string, node: Element): void;
    evaluateNode(node: Element): AuditoryDescription[];
    toString(): string;
    runInSetting(settings: {
        [feature: string]: string | boolean;
    }, callback: () => AuditoryDescription[]): AuditoryDescription[];
    static addStore(set: RulesJson): void;
    processGrammar(context: SpeechRuleContext, node: Element, grammar: GrammarState): void;
    addEvaluator(store: BaseRuleStore): void;
    getEvaluator(locale: string, modality: string): (p1: Element) => AuditoryDescription[];
    enumerate(opt_info?: {
        [key: string]: any;
    }): {
        [key: string]: any;
    };
    private constructor();
    private evaluateNode_;
    private evaluateTree_;
    private evaluateNodeList_;
    private addLayout;
    private addPersonality_;
    private addExternalAttributes_;
    private addRelativePersonality_;
    private updateConstraint_;
    private makeSet_;
    lookupRule(node: Element, dynamic: DynamicCstr): SpeechRule;
    lookupRules(node: Element, dynamic: DynamicCstr): SpeechRule[];
    private pickMostConstraint_;
}
