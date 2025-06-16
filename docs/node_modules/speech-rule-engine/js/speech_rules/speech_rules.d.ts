import { SpeechRuleFunction } from '../rule_engine/speech_rule_functions.js';
export declare function addStore(constr: string, inherit: string, store: {
    [key: string]: SpeechRuleFunction;
}): void;
export declare function getStore(locale: string, modality: string, domain: string): {
    [key: string]: SpeechRuleFunction;
};
