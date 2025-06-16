import { AuditoryDescription } from '../audio/auditory_description.js';
export interface SpeechRuleEvaluator {
    evaluateDefault(node: Node): void;
    evaluateWhitespace(str: string): AuditoryDescription[];
    evaluateString(str: string): AuditoryDescription[];
    evaluateCustom(str: string): AuditoryDescription;
    evaluateCharacter(str: string): AuditoryDescription;
}
