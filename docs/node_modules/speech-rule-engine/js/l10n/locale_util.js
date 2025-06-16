"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.nestingToString = nestingToString;
exports.combinePostfixIndex = combinePostfixIndex;
exports.localFont = localFont;
exports.localRole = localRole;
exports.localEnclose = localEnclose;
exports.localeFontCombiner = localeFontCombiner;
const locale_js_1 = require("./locale.js");
const transformers_js_1 = require("./transformers.js");
function nestingToString(count) {
    switch (count) {
        case 1:
            return locale_js_1.LOCALE.MESSAGES.MS.ONCE || '';
        case 2:
            return locale_js_1.LOCALE.MESSAGES.MS.TWICE;
        default:
            return count.toString();
    }
}
function combinePostfixIndex(postfix, index) {
    return postfix === locale_js_1.LOCALE.MESSAGES.MS.ROOTINDEX ||
        postfix === locale_js_1.LOCALE.MESSAGES.MS.INDEX
        ? postfix
        : postfix + ' ' + index;
}
function localFont(font) {
    return extractString(locale_js_1.LOCALE.MESSAGES.font[font], font);
}
function localRole(role) {
    return extractString(locale_js_1.LOCALE.MESSAGES.role[role], role);
}
function localEnclose(enclose) {
    return extractString(locale_js_1.LOCALE.MESSAGES.enclose[enclose], enclose);
}
function extractString(combiner, fallback) {
    if (combiner === undefined) {
        return fallback;
    }
    return typeof combiner === 'string' ? combiner : combiner[0];
}
function localeFontCombiner(font) {
    return typeof font === 'string'
        ? { font: font, combiner: locale_js_1.LOCALE.ALPHABETS.combiner }
        : {
            font: font[0],
            combiner: locale_js_1.LOCALE.COMBINERS[font[1]] ||
                transformers_js_1.Combiners[font[1]] ||
                locale_js_1.LOCALE.ALPHABETS.combiner
        };
}
