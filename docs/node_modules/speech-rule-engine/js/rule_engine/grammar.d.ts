type Value = boolean | string;
export type State = {
    [key: string]: Value;
};
interface Flags {
    adjust?: boolean;
    preprocess?: boolean;
    correct?: boolean;
    translate?: boolean;
}
type Correction = (text: string, parameter?: Value) => string;
export declare const ATTRIBUTE = "grammar";
export declare class Grammar {
    private static instance;
    currentFlags: Flags;
    private parameters_;
    private corrections_;
    private preprocessors_;
    private stateStack_;
    private singles;
    static getInstance(): Grammar;
    static parseInput(grammar: string): State;
    static parseState(stateStr: string): State;
    private static translateString;
    private static translateUnit;
    private static prepareUnit;
    private static cleanUnit;
    clear(): void;
    setParameter(parameter: string, value: Value): Value;
    getParameter(parameter: string): Value;
    setCorrection(correction: string, func: Correction): void;
    setPreprocessor(preprocessor: string, func: Correction): void;
    getCorrection(correction: string): Correction;
    getState(): string;
    processSingles(): void;
    pushState(assignment: {
        [key: string]: Value;
    }): void;
    popState(): void;
    setAttribute(node: Element): void;
    preprocess(text: string): string;
    correct(text: string): string;
    apply(text: string, opt_flags?: Flags): string;
    private runProcessors;
    private constructor();
}
export declare function correctFont(text: string, correction: string): string;
export {};
