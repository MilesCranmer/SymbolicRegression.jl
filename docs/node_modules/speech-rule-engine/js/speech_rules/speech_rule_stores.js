"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.init = init;
const clearspeak_rules_js_1 = require("./clearspeak_rules.js");
const mathspeak_rules_js_1 = require("./mathspeak_rules.js");
const other_rules_js_1 = require("./other_rules.js");
let INIT = false;
function init() {
    if (INIT) {
        return;
    }
    (0, mathspeak_rules_js_1.MathspeakRules)();
    (0, clearspeak_rules_js_1.ClearspeakRules)();
    (0, other_rules_js_1.PrefixRules)();
    (0, other_rules_js_1.OtherRules)();
    (0, other_rules_js_1.BrailleRules)();
    INIT = true;
}
