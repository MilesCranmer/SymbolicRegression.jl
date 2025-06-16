import { SemanticMeaning, SemanticSecondary } from './semantic_meaning.js';
export declare const NamedSymbol: {
    functionApplication: string;
    invisibleTimes: string;
    invisibleComma: string;
    invisiblePlus: string;
};
declare class meaningMap extends Map<string, SemanticMeaning> {
    get(symbol: string): SemanticMeaning;
}
declare class secondaryMap extends Map<string, string> {
    set(char: string, kind: SemanticSecondary, annotation?: string): this;
    has(char: string, kind?: SemanticSecondary): boolean;
    get(char: string, kind?: SemanticSecondary): string;
    private secKey;
}
export declare const SemanticMap: {
    Meaning: meaningMap;
    Secondary: secondaryMap;
    FencesHoriz: Map<any, any>;
    FencesVert: Map<any, any>;
    LatexCommands: Map<any, any>;
};
export declare function addFunctionSemantic(base: string, names: string[]): void;
export declare function equal(meaning1: SemanticMeaning, meaning2: SemanticMeaning): boolean;
export declare function isMatchingFence(open: string, close: string): boolean;
export {};
