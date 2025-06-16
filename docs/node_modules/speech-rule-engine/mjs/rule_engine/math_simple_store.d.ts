import { DynamicCstr } from './dynamic_cstr.js';
export interface MappingsJson {
    default: {
        [key: string]: string;
    };
    [domainName: string]: {
        [key: string]: string;
    };
}
export interface BaseJson {
    key: string;
    category: string;
    names?: string[];
    si?: boolean;
}
export interface UnicodeJson extends BaseJson {
    mappings: MappingsJson;
    modality?: string;
    locale?: string;
    domain?: string;
}
export interface SiJson {
    [key: string]: string;
}
export interface SimpleRule {
    cstr: DynamicCstr;
    action: string;
}
export declare class MathSimpleStore {
    base: BaseJson;
    rules: Map<string, SimpleRule[]>;
    static parseUnicode(num: string): string;
    private static testDynamicConstraints_;
    defineRulesFromMappings(locale: string, modality: string, mapping: MappingsJson): void;
    getRules(key: string): SimpleRule[];
    defineRuleFromStrings(locale: string, modality: string, domain: string, style: string, content: string): void;
    lookupRule(_node: Node, dynamic: DynamicCstr): SimpleRule;
}
