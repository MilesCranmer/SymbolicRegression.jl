"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.unitMultipliers = unitMultipliers;
exports.oneLeft = oneLeft;
const auditory_description_js_1 = require("../audio/auditory_description.js");
const XpathUtil = require("../common/xpath_util.js");
const locale_js_1 = require("../l10n/locale.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
function unitMultipliers(nodes, _context) {
    const children = nodes;
    let counter = 0;
    return function () {
        const descr = auditory_description_js_1.AuditoryDescription.create({
            text: rightMostUnit(children[counter]) &&
                leftMostUnit(children[counter + 1])
                ? locale_js_1.LOCALE.MESSAGES.unitTimes
                : ''
        }, {});
        counter++;
        return [descr];
    };
}
const SCRIPT_ELEMENTS = [
    semantic_meaning_js_1.SemanticType.SUPERSCRIPT,
    semantic_meaning_js_1.SemanticType.SUBSCRIPT,
    semantic_meaning_js_1.SemanticType.OVERSCORE,
    semantic_meaning_js_1.SemanticType.UNDERSCORE
];
function rightMostUnit(node) {
    while (node) {
        if (node.getAttribute('role') === 'unit') {
            return true;
        }
        const tag = node.tagName;
        const children = XpathUtil.evalXPath('children/*', node);
        node = (SCRIPT_ELEMENTS.indexOf(tag) !== -1
            ? children[0]
            : children[children.length - 1]);
    }
    return false;
}
function leftMostUnit(node) {
    while (node) {
        if (node.getAttribute('role') === 'unit') {
            return true;
        }
        const children = XpathUtil.evalXPath('children/*', node);
        node = children[0];
    }
    return false;
}
function oneLeft(node) {
    while (node) {
        if (node.tagName === 'number' && node.textContent === '1') {
            return [node];
        }
        if (node.tagName !== 'infixop' ||
            (node.getAttribute('role') !== 'multiplication' &&
                node.getAttribute('role') !== 'implicit')) {
            return [];
        }
        node = XpathUtil.evalXPath('children/*', node)[0];
    }
    return [];
}
