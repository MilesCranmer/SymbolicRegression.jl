import { SpeechRule } from './speech_rule.js';
import { SpeechRuleContext } from './speech_rule_context.js';
export interface SpeechRuleStore {
    context: SpeechRuleContext;
    addRule(rule: SpeechRule): void;
    deleteRule(rule: SpeechRule): void;
    findRule(pred: (rule: SpeechRule) => boolean): SpeechRule;
    findAllRules(pred: (rule: SpeechRule) => boolean): SpeechRule[];
    defineRule(name: string, dynamic: string, action: string, pre: string, ...args: string[]): SpeechRule;
}
