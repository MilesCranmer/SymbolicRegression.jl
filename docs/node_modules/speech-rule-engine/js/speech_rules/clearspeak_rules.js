"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ClearspeakRules = ClearspeakRules;
const dynamic_cstr_js_1 = require("../rule_engine/dynamic_cstr.js");
const StoreUtil = require("../rule_engine/store_util.js");
const ClearspeakUtil = require("./clearspeak_util.js");
const MathspeakUtil = require("./mathspeak_util.js");
const NumbersUtil = require("./numbers_util.js");
const SpeechRules = require("./speech_rules.js");
function ClearspeakRules() {
    SpeechRules.addStore(dynamic_cstr_js_1.DynamicCstr.BASE_LOCALE + '.speech.clearspeak', '', {
        CTFpauseSeparator: StoreUtil.pauseSeparator,
        CTFnodeCounter: ClearspeakUtil.nodeCounter,
        CTFcontentIterator: StoreUtil.contentIterator,
        CSFvulgarFraction: NumbersUtil.vulgarFraction,
        CQFvulgarFractionSmall: ClearspeakUtil.isSmallVulgarFraction,
        CQFcellsSimple: ClearspeakUtil.allCellsSimple,
        CSFordinalExponent: ClearspeakUtil.ordinalExponent,
        CSFwordOrdinal: ClearspeakUtil.wordOrdinal,
        CQFmatchingFences: ClearspeakUtil.matchingFences,
        CSFnestingDepth: ClearspeakUtil.nestingDepth,
        CQFfencedArguments: ClearspeakUtil.fencedArguments,
        CQFsimpleArguments: ClearspeakUtil.simpleArguments,
        CQFspaceoutNumber: MathspeakUtil.spaceoutNumber
    });
}
