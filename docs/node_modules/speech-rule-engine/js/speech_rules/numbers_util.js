"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ordinalCounter = ordinalCounter;
exports.wordCounter = wordCounter;
exports.vulgarFraction = vulgarFraction;
exports.ordinalPosition = ordinalPosition;
const span_js_1 = require("../audio/span.js");
const DomUtil = require("../common/dom_util.js");
const locale_js_1 = require("../l10n/locale.js");
const transformers_js_1 = require("../l10n/transformers.js");
function ordinalCounter(_node, context) {
    let counter = 0;
    return function () {
        return locale_js_1.LOCALE.NUMBERS.numericOrdinal(++counter) + ' ' + context;
    };
}
function wordCounter(_node, context) {
    let counter = 0;
    return function () {
        return locale_js_1.LOCALE.NUMBERS.numberToOrdinal(++counter, false) + ' ' + context;
    };
}
function vulgarFraction(node) {
    const conversion = (0, transformers_js_1.convertVulgarFraction)(node, locale_js_1.LOCALE.MESSAGES.MS.FRAC_OVER);
    if (conversion.convertible &&
        conversion.enumerator &&
        conversion.denominator) {
        return [
            span_js_1.Span.node(locale_js_1.LOCALE.NUMBERS.numberToWords(conversion.enumerator), node.childNodes[0].childNodes[0], { separator: '' }),
            span_js_1.Span.stringAttr(locale_js_1.LOCALE.NUMBERS.vulgarSep, { separator: '' }),
            span_js_1.Span.node(locale_js_1.LOCALE.NUMBERS.numberToOrdinal(conversion.denominator, conversion.enumerator !== 1), node.childNodes[0].childNodes[1])
        ];
    }
    return [span_js_1.Span.node(conversion.content || '', node)];
}
function ordinalPosition(node) {
    const children = DomUtil.toArray(node.parentNode.childNodes);
    return span_js_1.Span.singleton(locale_js_1.LOCALE.NUMBERS.numericOrdinal(children.indexOf(node) + 1).toString());
}
