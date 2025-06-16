"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Combiners = void 0;
exports.pluralCase = pluralCase;
exports.identityTransformer = identityTransformer;
exports.siCombiner = siCombiner;
exports.convertVulgarFraction = convertVulgarFraction;
exports.vulgarFractionSmall = vulgarFractionSmall;
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
function pluralCase(num, _plural) {
    return num.toString();
}
function identityTransformer(input) {
    return input.toString();
}
function siCombiner(prefix, unit) {
    return prefix + unit.toLowerCase();
}
exports.Combiners = {};
exports.Combiners.identityCombiner = function (a, b, c) {
    return a + b + c;
};
exports.Combiners.prefixCombiner = function (letter, font, cap) {
    letter = cap ? cap + ' ' + letter : letter;
    return font ? font + ' ' + letter : letter;
};
exports.Combiners.postfixCombiner = function (letter, font, cap) {
    letter = cap ? cap + ' ' + letter : letter;
    return font ? letter + ' ' + font : letter;
};
exports.Combiners.romanceCombiner = function (letter, font, cap) {
    letter = cap ? letter + ' ' + cap : letter;
    return font ? letter + ' ' + font : letter;
};
function convertVulgarFraction(node, over = '') {
    if (!node.childNodes ||
        !node.childNodes[0] ||
        !node.childNodes[0].childNodes ||
        node.childNodes[0].childNodes.length < 2 ||
        node.childNodes[0].childNodes[0].tagName !==
            semantic_meaning_js_1.SemanticType.NUMBER ||
        node.childNodes[0].childNodes[0].getAttribute('role') !==
            semantic_meaning_js_1.SemanticRole.INTEGER ||
        node.childNodes[0].childNodes[1].tagName !==
            semantic_meaning_js_1.SemanticType.NUMBER ||
        node.childNodes[0].childNodes[1].getAttribute('role') !==
            semantic_meaning_js_1.SemanticRole.INTEGER) {
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
function vulgarFractionSmall(node, enumer, denom) {
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
