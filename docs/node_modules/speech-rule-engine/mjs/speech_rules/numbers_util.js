import { Span } from '../audio/span.js';
import * as DomUtil from '../common/dom_util.js';
import { LOCALE } from '../l10n/locale.js';
import { convertVulgarFraction } from '../l10n/transformers.js';
export function ordinalCounter(_node, context) {
    let counter = 0;
    return function () {
        return LOCALE.NUMBERS.numericOrdinal(++counter) + ' ' + context;
    };
}
export function wordCounter(_node, context) {
    let counter = 0;
    return function () {
        return LOCALE.NUMBERS.numberToOrdinal(++counter, false) + ' ' + context;
    };
}
export function vulgarFraction(node) {
    const conversion = convertVulgarFraction(node, LOCALE.MESSAGES.MS.FRAC_OVER);
    if (conversion.convertible &&
        conversion.enumerator &&
        conversion.denominator) {
        return [
            Span.node(LOCALE.NUMBERS.numberToWords(conversion.enumerator), node.childNodes[0].childNodes[0], { separator: '' }),
            Span.stringAttr(LOCALE.NUMBERS.vulgarSep, { separator: '' }),
            Span.node(LOCALE.NUMBERS.numberToOrdinal(conversion.denominator, conversion.enumerator !== 1), node.childNodes[0].childNodes[1])
        ];
    }
    return [Span.node(conversion.content || '', node)];
}
export function ordinalPosition(node) {
    const children = DomUtil.toArray(node.parentNode.childNodes);
    return Span.singleton(LOCALE.NUMBERS.numericOrdinal(children.indexOf(node) + 1).toString());
}
