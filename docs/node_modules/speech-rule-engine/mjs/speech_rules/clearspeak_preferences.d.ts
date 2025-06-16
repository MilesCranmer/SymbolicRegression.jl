import { DynamicCstr } from '../rule_engine/dynamic_cstr.js';
import { AxisMap, AxisProperties, DefaultComparator, DynamicProperties } from '../rule_engine/dynamic_cstr.js';
import { SemanticNode } from '../semantic_tree/semantic_node.js';
export declare class ClearspeakPreferences extends DynamicCstr {
    preference: {
        [key: string]: string;
    };
    private static AUTO;
    static comparator(): Comparator;
    static fromPreference(pref: string): AxisMap;
    static toPreference(pref: AxisMap): string;
    static getLocalePreferences(opt_dynamic?: {
        [key: string]: AxisProperties;
    }): {
        [key: string]: AxisProperties;
    };
    static currentPreference(): string;
    static relevantPreferences(node: SemanticNode): string;
    static findPreference(prefs: string, kind: string): string;
    static addPreference(prefs: string, kind: string, value: string): string;
    private static getLocalePreferences_;
    constructor(cstr: AxisMap, preference: {
        [key: string]: string;
    });
    equal(cstr: ClearspeakPreferences): boolean;
}
declare class Comparator extends DefaultComparator {
    preference: AxisMap;
    constructor(cstr: DynamicCstr, props: DynamicProperties);
    match(cstr: DynamicCstr): boolean;
    compare(cstr1: DynamicCstr, cstr2: DynamicCstr): 0 | 1 | -1;
}
export {};
