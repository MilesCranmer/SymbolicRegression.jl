import { DynamicCstr } from '../rule_engine/dynamic_cstr.js';
import * as StoreUtil from '../rule_engine/store_util.js';
import * as ClearspeakUtil from './clearspeak_util.js';
import * as MathspeakUtil from './mathspeak_util.js';
import * as NumbersUtil from './numbers_util.js';
import * as SpeechRules from './speech_rules.js';
export function ClearspeakRules() {
    SpeechRules.addStore(DynamicCstr.BASE_LOCALE + '.speech.clearspeak', '', {
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
