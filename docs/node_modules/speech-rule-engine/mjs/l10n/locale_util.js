import { LOCALE } from './locale.js';
import { Combiners } from './transformers.js';
export function nestingToString(count) {
    switch (count) {
        case 1:
            return LOCALE.MESSAGES.MS.ONCE || '';
        case 2:
            return LOCALE.MESSAGES.MS.TWICE;
        default:
            return count.toString();
    }
}
export function combinePostfixIndex(postfix, index) {
    return postfix === LOCALE.MESSAGES.MS.ROOTINDEX ||
        postfix === LOCALE.MESSAGES.MS.INDEX
        ? postfix
        : postfix + ' ' + index;
}
export function localFont(font) {
    return extractString(LOCALE.MESSAGES.font[font], font);
}
export function localRole(role) {
    return extractString(LOCALE.MESSAGES.role[role], role);
}
export function localEnclose(enclose) {
    return extractString(LOCALE.MESSAGES.enclose[enclose], enclose);
}
function extractString(combiner, fallback) {
    if (combiner === undefined) {
        return fallback;
    }
    return typeof combiner === 'string' ? combiner : combiner[0];
}
export function localeFontCombiner(font) {
    return typeof font === 'string'
        ? { font: font, combiner: LOCALE.ALPHABETS.combiner }
        : {
            font: font[0],
            combiner: LOCALE.COMBINERS[font[1]] ||
                Combiners[font[1]] ||
                LOCALE.ALPHABETS.combiner
        };
}
