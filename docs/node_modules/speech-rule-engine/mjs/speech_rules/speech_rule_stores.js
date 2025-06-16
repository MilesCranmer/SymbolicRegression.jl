import { ClearspeakRules } from './clearspeak_rules.js';
import { MathspeakRules } from './mathspeak_rules.js';
import { BrailleRules, OtherRules, PrefixRules } from './other_rules.js';
let INIT = false;
export function init() {
    if (INIT) {
        return;
    }
    MathspeakRules();
    ClearspeakRules();
    PrefixRules();
    OtherRules();
    BrailleRules();
    INIT = true;
}
