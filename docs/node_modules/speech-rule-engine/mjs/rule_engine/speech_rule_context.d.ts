import { Span, SpanAttrs } from '../audio/span.js';
import * as srf from './speech_rule_functions.js';
export declare class SpeechRuleContext {
    customQueries: srf.CustomQueries;
    customStrings: srf.CustomStrings;
    contextFunctions: srf.ContextFunctions;
    customGenerators: srf.CustomGenerators;
    applyCustomQuery(node: Element, funcName: string): Element[];
    applySelector(node: Element, expr: string): Element[];
    applyQuery(node: Element, expr: string): Element;
    applyConstraint(node: Element, expr: string): boolean;
    constructString(node: Element, expr: string): string;
    constructSpan(node: Element, expr: string, def: SpanAttrs): Span[];
    private constructString_;
    parse(functions: [string, srf.SpeechRuleFunction][] | {
        [key: string]: srf.SpeechRuleFunction;
    }): void;
}
