import { SpeechRuleContext } from '../rule_engine/speech_rule_context.js';
import { TrieNode, TrieNodeKind } from './trie_node.js';
export declare function getNode(kind: TrieNodeKind, constraint: string, context: SpeechRuleContext): TrieNode | null;
