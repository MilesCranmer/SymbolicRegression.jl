import { Engine } from '../common/engine.js';
import { Variables } from '../common/variables.js';
import { Grammar } from '../rule_engine/grammar.js';
import { af } from './locales/locale_af.js';
import { ca } from './locales/locale_ca.js';
import { da } from './locales/locale_da.js';
import { de } from './locales/locale_de.js';
import { en } from './locales/locale_en.js';
import { es } from './locales/locale_es.js';
import { euro } from './locales/locale_euro.js';
import { fr } from './locales/locale_fr.js';
import { hi } from './locales/locale_hi.js';
import { ko } from './locales/locale_ko.js';
import { it } from './locales/locale_it.js';
import { nb } from './locales/locale_nb.js';
import { nemeth } from './locales/locale_nemeth.js';
import { nn } from './locales/locale_nn.js';
import { sv } from './locales/locale_sv.js';
import { LOCALE } from './locale.js';
export const locales = {
    af: af,
    ca: ca,
    da: da,
    de: de,
    en: en,
    es: es,
    euro: euro,
    fr: fr,
    hi: hi,
    it: it,
    ko: ko,
    nb: nb,
    nn: nn,
    sv: sv,
    nemeth: nemeth
};
export function setLocale() {
    const msgs = getLocale();
    setSubiso(msgs);
    if (msgs) {
        for (const key of Object.getOwnPropertyNames(msgs)) {
            LOCALE[key] = msgs[key];
        }
        for (const [key, func] of Object.entries(msgs.CORRECTIONS)) {
            Grammar.getInstance().setCorrection(key, func);
        }
    }
}
function setSubiso(msg) {
    const subiso = Engine.getInstance().subiso;
    if (msg.SUBISO.all.indexOf(subiso) === -1) {
        Engine.getInstance().subiso = msg.SUBISO.default;
    }
    msg.SUBISO.current = Engine.getInstance().subiso;
}
function getLocale() {
    const locale = Variables.ensureLocale(Engine.getInstance().locale, Engine.getInstance().defaultLocale);
    Engine.getInstance().locale = locale;
    return locales[locale]();
}
export function completeLocale(json) {
    const locale = locales[json.locale];
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
