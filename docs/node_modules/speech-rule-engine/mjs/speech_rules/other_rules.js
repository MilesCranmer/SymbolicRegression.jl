import { DynamicCstr } from '../rule_engine/dynamic_cstr.js';
import * as StoreUtil from '../rule_engine/store_util.js';
import * as MathspeakKoreanUtil from './mathspeak_korean_util.js';
import * as MathspeakUtil from './mathspeak_util.js';
import * as NemethUtil from './nemeth_util.js';
import * as NumbersUtil from './numbers_util.js';
import * as SpeechRules from './speech_rules.js';
export function PrefixRules() {
    SpeechRules.addStore('en.prefix.default', '', {
        CSFordinalPosition: NumbersUtil.ordinalPosition
    });
}
export function OtherRules() {
    SpeechRules.addStore('en.speech.chromevox', '', {
        CTFnodeCounter: StoreUtil.nodeCounter,
        CTFcontentIterator: StoreUtil.contentIterator
    });
    SpeechRules.addStore('en.speech.emacspeak', 'en.speech.chromevox', {
        CQFvulgarFractionSmall: MathspeakUtil.isSmallVulgarFraction,
        CSFvulgarFraction: NumbersUtil.vulgarFraction
    });
    SpeechRules.addStore('ko.summary.', 'ko.speech.mathspeak', {
        CSFordinalConversion: MathspeakKoreanUtil.ordinalConversion,
        CSFdecreasedOrdinalConversion: MathspeakKoreanUtil.decreasedOrdinalConversion,
        CSFlistOrdinalConversion: MathspeakKoreanUtil.listOrdinalConversion
    });
}
export function BrailleRules() {
    SpeechRules.addStore('nemeth.braille.default', DynamicCstr.BASE_LOCALE + '.speech.mathspeak', {
        CSFopenFraction: NemethUtil.openingFraction,
        CSFcloseFraction: NemethUtil.closingFraction,
        CSFoverFraction: NemethUtil.overFraction,
        CSFoverBevFraction: NemethUtil.overBevelledFraction,
        CQFhyperFraction: NemethUtil.hyperFractionBoundary,
        CSFopenRadical: NemethUtil.openingRadical,
        CSFcloseRadical: NemethUtil.closingRadical,
        CSFindexRadical: NemethUtil.indexRadical,
        CSFsubscript: MathspeakUtil.subscriptVerbose,
        CSFsuperscript: MathspeakUtil.superscriptVerbose,
        CSFbaseline: MathspeakUtil.baselineVerbose,
        CGFtensorRules: (st) => MathspeakUtil.generateTensorRules(st, false),
        CTFcontentIterator: NemethUtil.contentIterator,
        CTFrelationIterator: NemethUtil.relationIterator,
        CTFimplicitIterator: NemethUtil.implicitIterator
    });
    SpeechRules.addStore('euro.braille.default', 'nemeth.braille.default', {});
}
