"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.locales = void 0;
exports.setLocale = setLocale;
exports.completeLocale = completeLocale;
const engine_js_1 = require("../common/engine.js");
const variables_js_1 = require("../common/variables.js");
const grammar_js_1 = require("../rule_engine/grammar.js");
const locale_af_js_1 = require("./locales/locale_af.js");
const locale_ca_js_1 = require("./locales/locale_ca.js");
const locale_da_js_1 = require("./locales/locale_da.js");
const locale_de_js_1 = require("./locales/locale_de.js");
const locale_en_js_1 = require("./locales/locale_en.js");
const locale_es_js_1 = require("./locales/locale_es.js");
const locale_euro_js_1 = require("./locales/locale_euro.js");
const locale_fr_js_1 = require("./locales/locale_fr.js");
const locale_hi_js_1 = require("./locales/locale_hi.js");
const locale_ko_js_1 = require("./locales/locale_ko.js");
const locale_it_js_1 = require("./locales/locale_it.js");
const locale_nb_js_1 = require("./locales/locale_nb.js");
const locale_nemeth_js_1 = require("./locales/locale_nemeth.js");
const locale_nn_js_1 = require("./locales/locale_nn.js");
const locale_sv_js_1 = require("./locales/locale_sv.js");
const locale_js_1 = require("./locale.js");
exports.locales = {
    af: locale_af_js_1.af,
    ca: locale_ca_js_1.ca,
    da: locale_da_js_1.da,
    de: locale_de_js_1.de,
    en: locale_en_js_1.en,
    es: locale_es_js_1.es,
    euro: locale_euro_js_1.euro,
    fr: locale_fr_js_1.fr,
    hi: locale_hi_js_1.hi,
    it: locale_it_js_1.it,
    ko: locale_ko_js_1.ko,
    nb: locale_nb_js_1.nb,
    nn: locale_nn_js_1.nn,
    sv: locale_sv_js_1.sv,
    nemeth: locale_nemeth_js_1.nemeth
};
function setLocale() {
    const msgs = getLocale();
    setSubiso(msgs);
    if (msgs) {
        for (const key of Object.getOwnPropertyNames(msgs)) {
            locale_js_1.LOCALE[key] = msgs[key];
        }
        for (const [key, func] of Object.entries(msgs.CORRECTIONS)) {
            grammar_js_1.Grammar.getInstance().setCorrection(key, func);
        }
    }
}
function setSubiso(msg) {
    const subiso = engine_js_1.Engine.getInstance().subiso;
    if (msg.SUBISO.all.indexOf(subiso) === -1) {
        engine_js_1.Engine.getInstance().subiso = msg.SUBISO.default;
    }
    msg.SUBISO.current = engine_js_1.Engine.getInstance().subiso;
}
function getLocale() {
    const locale = variables_js_1.Variables.ensureLocale(engine_js_1.Engine.getInstance().locale, engine_js_1.Engine.getInstance().defaultLocale);
    engine_js_1.Engine.getInstance().locale = locale;
    return exports.locales[locale]();
}
function completeLocale(json) {
    const locale = exports.locales[json.locale];
    if (!locale) {
        console.error('Locale ' + json.locale + ' does not exist!');
        return;
    }
    const kind = json.kind.toUpperCase();
    const messages = json.messages;
    if (!messages)
        return;
    const loc = locale();
    for (const [key, value] of Object.entries(messages)) {
        loc[kind][key] = value;
    }
}
