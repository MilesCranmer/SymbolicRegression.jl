"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PrefixRules = PrefixRules;
exports.OtherRules = OtherRules;
exports.BrailleRules = BrailleRules;
const dynamic_cstr_js_1 = require("../rule_engine/dynamic_cstr.js");
const StoreUtil = require("../rule_engine/store_util.js");
const MathspeakKoreanUtil = require("./mathspeak_korean_util.js");
const MathspeakUtil = require("./mathspeak_util.js");
const NemethUtil = require("./nemeth_util.js");
const NumbersUtil = require("./numbers_util.js");
const SpeechRules = require("./speech_rules.js");
function PrefixRules() {
    SpeechRules.addStore('en.prefix.default', '', {
        CSFordinalPosition: NumbersUtil.ordinalPosition
    });
}
function OtherRules() {
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
function BrailleRules() {
    SpeechRules.addStore('nemeth.braille.default', dynamic_cstr_js_1.DynamicCstr.BASE_LOCALE + '.speech.mathspeak', {
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
