import { MathStore } from './math_store.js';
import { AuditoryDescription } from '../audio/auditory_description.js';
export declare class BrailleStore extends MathStore {
    modality: string;
    customTranscriptions: {
        [key: string]: string;
    };
    evaluateString(str: string): AuditoryDescription[];
    annotations(): void;
}
export declare class EuroStore extends BrailleStore {
    locale: string;
    customTranscriptions: {};
    customCommands: {
        [key: string]: string;
    };
    evaluateString(str: string): AuditoryDescription[];
    protected cleanup(commands: string[]): string;
    private lastSpecial;
    private specialChars;
    private addSpace;
}
