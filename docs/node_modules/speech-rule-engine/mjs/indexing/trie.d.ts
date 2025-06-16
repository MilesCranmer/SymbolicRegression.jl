import { SpeechRule } from '../rule_engine/speech_rule.js';
import { TrieNode } from './trie_node.js';
export declare class Trie {
    root: TrieNode;
    static collectRules_(root: TrieNode): SpeechRule[];
    private static printWithDepth_;
    private static order_;
    constructor();
    addRule(rule: SpeechRule): void;
    lookupRules(xml: Element, dynamic: string[][]): SpeechRule[];
    hasSubtrie(cstrs: string[]): boolean;
    toString(): string;
    collectRules(root?: TrieNode): SpeechRule[];
    order(): number;
    enumerate(opt_info?: {
        [key: string]: any;
    }): {
        [key: string]: any;
    };
    byConstraint(constraint: string[]): TrieNode;
    private enumerate_;
    private addNode_;
}
