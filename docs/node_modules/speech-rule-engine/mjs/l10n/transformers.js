import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
export function pluralCase(num, _plural) {
    return num.toString();
}
export function identityTransformer(input) {
    return input.toString();
}
export function siCombiner(prefix, unit) {
    return prefix + unit.toLowerCase();
}
export const Combiners = {};
Combiners.identityCombiner = function (a, b, c) {
    return a + b + c;
};
Combiners.prefixCombiner = function (letter, font, cap) {
    letter = cap ? cap + ' ' + letter : letter;
    return font ? font + ' ' + letter : letter;
};
Combiners.postfixCombiner = function (letter, font, cap) {
    letter = cap ? cap + ' ' + letter : letter;
    return font ? letter + ' ' + font : letter;
};
Combiners.romanceCombiner = function (letter, font, cap) {
    letter = cap ? letter + ' ' + cap : letter;
    return font ? letter + ' ' + font : letter;
};
export function convertVulgarFraction(node, over = '') {
    if (!node.childNodes ||
        !node.childNodes[0] ||
        !node.childNodes[0].childNodes ||
        node.childNodes[0].childNodes.length < 2 ||
        node.childNodes[0].childNodes[0].tagName !==
            SemanticType.NUMBER ||
        node.childNodes[0].childNodes[0].getAttribute('role') !==
            SemanticRole.INTEGER ||
        node.childNodes[0].childNodes[1].tagName !==
            SemanticType.NUMBER ||
        node.childNodes[0].childNodes[1].getAttribute('role') !==
            SemanticRole.INTEGER) {
        return { convertible: false, content: node.textContent };
    }
    const denStr = node.childNodes[0].childNodes[1].textContent;
    const enumStr = node.childNodes[0].childNodes[0].textContent;
    const denominator = Number(denStr);
    const enumerator = Number(enumStr);
    if (isNaN(denominator) || isNaN(enumerator)) {
        return {
            convertible: false,
            content: `${enumStr} ${over} ${denStr}`
        };
    }
    return {
        convertible: true,
        enumerator: enumerator,
        denominator: denominator
    };
}
export function vulgarFractionSmall(node, enumer, denom) {
    const conversion = convertVulgarFraction(node);
    if (conversion.convertible) {
        const enumerator = conversion.enumerator;
        const denominator = conversion.denominator;
        return (enumerator > 0 &&
            enumerator < enumer &&
            denominator > 0 &&
            denominator < denom);
    }
    return false;
}
