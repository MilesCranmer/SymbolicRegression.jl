import { DynamicCstr } from '../rule_engine/dynamic_cstr.js';
import * as StoreUtil from '../rule_engine/store_util.js';
import * as MathspeakFrenchUtil from './mathspeak_french_util.js';
import * as MathspeakKoreanUtil from './mathspeak_korean_util.js';
import * as MathspeakUtil from './mathspeak_util.js';
import * as NumbersUtil from './numbers_util.js';
import * as SpeechRules from './speech_rules.js';
import * as UnitUtil from './unit_util.js';
export function MathspeakRules() {
    SpeechRules.addStore(DynamicCstr.BASE_LOCALE + '.speech.mathspeak', '', {
        CQFspaceoutNumber: MathspeakUtil.spaceoutNumber,
        CQFspaceoutIdentifier: MathspeakUtil.spaceoutIdentifier,
        CSFspaceoutText: MathspeakUtil.spaceoutText,
        CSFopenFracVerbose: MathspeakUtil.openingFractionVerbose,
        CSFcloseFracVerbose: MathspeakUtil.closingFractionVerbose,
        CSFoverFracVerbose: MathspeakUtil.overFractionVerbose,
        CSFopenFracBrief: MathspeakUtil.openingFractionBrief,
        CSFcloseFracBrief: MathspeakUtil.closingFractionBrief,
        CSFopenFracSbrief: MathspeakUtil.openingFractionSbrief,
        CSFcloseFracSbrief: MathspeakUtil.closingFractionSbrief,
        CSFoverFracSbrief: MathspeakUtil.overFractionSbrief,
        CSFvulgarFraction: NumbersUtil.vulgarFraction,
        CQFvulgarFractionSmall: MathspeakUtil.isSmallVulgarFraction,
        CSFopenRadicalVerbose: MathspeakUtil.openingRadicalVerbose,
        CSFcloseRadicalVerbose: MathspeakUtil.closingRadicalVerbose,
        CSFindexRadicalVerbose: MathspeakUtil.indexRadicalVerbose,
        CSFopenRadicalBrief: MathspeakUtil.openingRadicalBrief,
        CSFcloseRadicalBrief: MathspeakUtil.closingRadicalBrief,
        CSFindexRadicalBrief: MathspeakUtil.indexRadicalBrief,
        CSFopenRadicalSbrief: MathspeakUtil.openingRadicalSbrief,
        CSFindexRadicalSbrief: MathspeakUtil.indexRadicalSbrief,
        CQFisSmallRoot: MathspeakUtil.smallRoot,
        CSFsuperscriptVerbose: MathspeakUtil.superscriptVerbose,
        CSFsuperscriptBrief: MathspeakUtil.superscriptBrief,
        CSFsubscriptVerbose: MathspeakUtil.subscriptVerbose,
        CSFsubscriptBrief: MathspeakUtil.subscriptBrief,
        CSFbaselineVerbose: MathspeakUtil.baselineVerbose,
        CSFbaselineBrief: MathspeakUtil.baselineBrief,
        CSFleftsuperscriptVerbose: MathspeakUtil.superscriptVerbose,
        CSFleftsubscriptVerbose: MathspeakUtil.subscriptVerbose,
        CSFrightsuperscriptVerbose: MathspeakUtil.superscriptVerbose,
        CSFrightsubscriptVerbose: MathspeakUtil.subscriptVerbose,
        CSFleftsuperscriptBrief: MathspeakUtil.superscriptBrief,
        CSFleftsubscriptBrief: MathspeakUtil.subscriptBrief,
        CSFrightsuperscriptBrief: MathspeakUtil.superscriptBrief,
        CSFrightsubscriptBrief: MathspeakUtil.subscriptBrief,
        CSFunderscript: MathspeakUtil.nestedUnderscript,
        CSFoverscript: MathspeakUtil.nestedOverscript,
        CSFendscripts: MathspeakUtil.endscripts,
        CTFordinalCounter: NumbersUtil.ordinalCounter,
        CTFwordCounter: NumbersUtil.wordCounter,
        CTFcontentIterator: StoreUtil.contentIterator,
        CQFdetIsSimple: MathspeakUtil.determinantIsSimple,
        CSFRemoveParens: MathspeakUtil.removeParens,
        CQFresetNesting: MathspeakUtil.resetNestingDepth,
        CGFbaselineConstraint: MathspeakUtil.generateBaselineConstraint,
        CGFtensorRules: MathspeakUtil.generateTensorRules
    });
    SpeechRules.addStore('es.speech.mathspeak', DynamicCstr.BASE_LOCALE + '.speech.mathspeak', {
        CTFunitMultipliers: UnitUtil.unitMultipliers,
        CQFoneLeft: UnitUtil.oneLeft
    });
    SpeechRules.addStore('fr.speech.mathspeak', DynamicCstr.BASE_LOCALE + '.speech.mathspeak', {
        CSFbaselineVerbose: MathspeakFrenchUtil.baselineVerbose,
        CSFbaselineBrief: MathspeakFrenchUtil.baselineBrief,
        CSFleftsuperscriptVerbose: MathspeakFrenchUtil.leftSuperscriptVerbose,
        CSFleftsubscriptVerbose: MathspeakFrenchUtil.leftSubscriptVerbose,
        CSFleftsuperscriptBrief: MathspeakFrenchUtil.leftSuperscriptBrief,
        CSFleftsubscriptBrief: MathspeakFrenchUtil.leftSubscriptBrief
    });
    SpeechRules.addStore('ko.speech.mathspeak', DynamicCstr.BASE_LOCALE + '.speech.mathspeak', {
        CSFopenFracVerbose: MathspeakKoreanUtil.openingFractionVerbose,
        CSFcloseFracVerbose: MathspeakKoreanUtil.closingFractionVerbose,
        CSFopenFracBrief: MathspeakKoreanUtil.openingFractionBrief,
        CSFcloseFracBrief: MathspeakKoreanUtil.closingFractionBrief,
        CSFopenFracSbrief: MathspeakKoreanUtil.openingFractionSbrief,
        CSFoverFracSbrief: MathspeakKoreanUtil.overFractionSbrief,
        CSFcloseFracSbrief: MathspeakKoreanUtil.closingFractionSbrief,
        CQFisSimpleIndex: MathspeakKoreanUtil.isSimpleIndex,
        CSFindexRadicalVerbose: MathspeakKoreanUtil.indexRadicalVerbose,
        CSFindexRadicalBrief: MathspeakKoreanUtil.indexRadicalBrief,
        CSFindexRadicalSbrief: MathspeakKoreanUtil.indexRadicalSbrief,
        CSFopenRadicalVerbose: MathspeakKoreanUtil.openingRadicalVerbose,
        CSFcloseRadicalVerbose: MathspeakKoreanUtil.closingRadicalVerbose,
        CSFopenRadicalBrief: MathspeakKoreanUtil.openingRadicalBrief,
        CSFcloseRadicalBrief: MathspeakKoreanUtil.closingRadicalBrief,
        CSFopenRadicalSbrief: MathspeakKoreanUtil.openingRadicalSbrief
    });
}
