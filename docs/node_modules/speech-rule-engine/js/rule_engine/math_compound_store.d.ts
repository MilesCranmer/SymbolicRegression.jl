import { BaseJson, MathSimpleStore, SiJson, MappingsJson, SimpleRule, UnicodeJson } from './math_simple_store.js';
import { DynamicCstr } from './dynamic_cstr.js';
export declare function changeLocale(json: UnicodeJson): boolean;
export declare function setSiPrefixes(prefixes: SiJson): void;
export declare const subStores: Map<string, MathSimpleStore>;
export declare const baseStores: Map<string, BaseJson>;
export declare function defineRules(base: string, str: string, mappings: MappingsJson): void;
export declare function defineRule(domain: string, style: string, str: string, content: string): void;
export declare function addSymbolRules(json: UnicodeJson[]): void;
export declare const addCharacterRules: (json: UnicodeJson[]) => void;
export declare function addFunctionRules(json: UnicodeJson[]): void;
export declare function addUnitRules(json: UnicodeJson[]): void;
export declare function lookupRule(node: string, dynamic: DynamicCstr): SimpleRule;
export declare function lookupCategory(character: string): string;
export declare function lookupString(text: string, dynamic: DynamicCstr): string;
export declare function enumerate(info?: {
    [key: string]: any;
}): {
    [key: string]: any;
};
export declare function reset(): void;
