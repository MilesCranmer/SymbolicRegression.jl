"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.nodeCounter = nodeCounter;
exports.allCellsSimple = allCellsSimple;
exports.isSmallVulgarFraction = isSmallVulgarFraction;
exports.ordinalExponent = ordinalExponent;
exports.nestingDepth = nestingDepth;
exports.matchingFences = matchingFences;
exports.fencedArguments = fencedArguments;
exports.simpleArguments = simpleArguments;
exports.wordOrdinal = wordOrdinal;
const span_js_1 = require("../audio/span.js");
const DomUtil = require("../common/dom_util.js");
const engine_js_1 = require("../common/engine.js");
const XpathUtil = require("../common/xpath_util.js");
const locale_js_1 = require("../l10n/locale.js");
const transformers_js_1 = require("../l10n/transformers.js");
const grammar_js_1 = require("../rule_engine/grammar.js");
const StoreUtil = require("../rule_engine/store_util.js");
const semantic_annotations_js_1 = require("../semantic_tree/semantic_annotations.js");
const semantic_annotator_js_1 = require("../semantic_tree/semantic_annotator.js");
const semantic_attr_js_1 = require("../semantic_tree/semantic_attr.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
function nodeCounter(nodes, context) {
    const split = context.split('-');
    const func = StoreUtil.nodeCounter(nodes, split[0] || '');
    const sep = split[1] || '';
    const init = split[2] || '';
    let first = true;
    return function () {
        const result = func();
        if (first) {
            first = false;
            return init + result + sep;
        }
        else {
            return result + sep;
        }
    };
}
function isSimpleExpression(node) {
    return (isSimpleNumber_(node) ||
        isSimpleLetters_(node) ||
        isSimpleDegree_(node) ||
        isSimpleNegative_(node) ||
        isSimpleFunction_(node));
}
function isSimpleFunction_(node) {
    return (node.type === semantic_meaning_js_1.SemanticType.APPL &&
        (node.childNodes[0].role === semantic_meaning_js_1.SemanticRole.PREFIXFUNC ||
            node.childNodes[0].role === semantic_meaning_js_1.SemanticRole.SIMPLEFUNC) &&
        (isSimple_(node.childNodes[1]) ||
            (node.childNodes[1].type === semantic_meaning_js_1.SemanticType.FENCED &&
                isSimple_(node.childNodes[1].childNodes[0]))));
}
function isSimpleNegative_(node) {
    return (node.type === semantic_meaning_js_1.SemanticType.PREFIXOP &&
        node.role === semantic_meaning_js_1.SemanticRole.NEGATIVE &&
        isSimple_(node.childNodes[0]) &&
        node.childNodes[0].type !== semantic_meaning_js_1.SemanticType.PREFIXOP &&
        node.childNodes[0].type !== semantic_meaning_js_1.SemanticType.APPL &&
        node.childNodes[0].type !== semantic_meaning_js_1.SemanticType.PUNCTUATED);
}
function isSimpleDegree_(node) {
    return (node.type === semantic_meaning_js_1.SemanticType.PUNCTUATED &&
        node.role === semantic_meaning_js_1.SemanticRole.ENDPUNCT &&
        node.childNodes.length === 2 &&
        node.childNodes[1].role === semantic_meaning_js_1.SemanticRole.DEGREE &&
        (isLetter_(node.childNodes[0]) ||
            isNumber_(node.childNodes[0]) ||
            (node.childNodes[0].type === semantic_meaning_js_1.SemanticType.PREFIXOP &&
                node.childNodes[0].role === semantic_meaning_js_1.SemanticRole.NEGATIVE &&
                (isLetter_(node.childNodes[0].childNodes[0]) ||
                    isNumber_(node.childNodes[0].childNodes[0])))));
}
function isSimpleLetters_(node) {
    return (isLetter_(node) ||
        (node.type === semantic_meaning_js_1.SemanticType.INFIXOP &&
            node.role === semantic_meaning_js_1.SemanticRole.IMPLICIT &&
            ((node.childNodes.length === 2 &&
                (isLetter_(node.childNodes[0]) ||
                    isSimpleNumber_(node.childNodes[0])) &&
                isLetter_(node.childNodes[1])) ||
                (node.childNodes.length === 3 &&
                    isSimpleNumber_(node.childNodes[0]) &&
                    isLetter_(node.childNodes[1]) &&
                    isLetter_(node.childNodes[2])))));
}
function isSimple_(node) {
    return node.hasAnnotation('clearspeak', 'simple');
}
function isLetter_(node) {
    return (node.type === semantic_meaning_js_1.SemanticType.IDENTIFIER &&
        (node.role === semantic_meaning_js_1.SemanticRole.LATINLETTER ||
            node.role === semantic_meaning_js_1.SemanticRole.GREEKLETTER ||
            node.role === semantic_meaning_js_1.SemanticRole.OTHERLETTER ||
            node.role === semantic_meaning_js_1.SemanticRole.SIMPLEFUNC));
}
function isNumber_(node) {
    return (node.type === semantic_meaning_js_1.SemanticType.NUMBER &&
        (node.role === semantic_meaning_js_1.SemanticRole.INTEGER || node.role === semantic_meaning_js_1.SemanticRole.FLOAT));
}
function isSimpleNumber_(node) {
    return isNumber_(node) || isSimpleFraction_(node);
}
function isSimpleFraction_(node) {
    if (hasPreference('Fraction_Over') || hasPreference('Fraction_FracOver')) {
        return false;
    }
    if (node.type !== semantic_meaning_js_1.SemanticType.FRACTION ||
        node.role !== semantic_meaning_js_1.SemanticRole.VULGAR) {
        return false;
    }
    if (hasPreference('Fraction_Ordinal')) {
        return true;
    }
    const enumerator = parseInt(node.childNodes[0].textContent, 10);
    const denominator = parseInt(node.childNodes[1].textContent, 10);
    return (enumerator > 0 && enumerator < 20 && denominator > 0 && denominator < 11);
}
function hasPreference(pref) {
    return engine_js_1.Engine.getInstance().style === pref;
}
(0, semantic_annotations_js_1.register)(new semantic_annotator_js_1.SemanticAnnotator('clearspeak', 'simple', function (node) {
    return isSimpleExpression(node) ? 'simple' : '';
}));
function simpleNode(node) {
    if (!node.hasAttribute('annotation')) {
        return false;
    }
    const annotation = node.getAttribute('annotation');
    return !!/clearspeak:simple$|clearspeak:simple;/.exec(annotation);
}
function simpleCell_(node) {
    if (simpleNode(node)) {
        return true;
    }
    if (node.tagName !== semantic_meaning_js_1.SemanticType.SUBSCRIPT) {
        return false;
    }
    const children = node.childNodes[0].childNodes;
    const index = children[1];
    return (children[0].tagName === semantic_meaning_js_1.SemanticType.IDENTIFIER &&
        (isInteger_(index) ||
            (index.tagName === semantic_meaning_js_1.SemanticType.INFIXOP &&
                index.hasAttribute('role') &&
                index.getAttribute('role') === semantic_meaning_js_1.SemanticRole.IMPLICIT &&
                allIndices_(index))));
}
function isInteger_(node) {
    return (node.tagName === semantic_meaning_js_1.SemanticType.NUMBER &&
        node.hasAttribute('role') &&
        node.getAttribute('role') === semantic_meaning_js_1.SemanticRole.INTEGER);
}
function allIndices_(node) {
    const nodes = XpathUtil.evalXPath('children/*', node);
    return nodes.every((x) => isInteger_(x) || x.tagName === semantic_meaning_js_1.SemanticType.IDENTIFIER);
}
function allCellsSimple(node) {
    const xpath = node.tagName === semantic_meaning_js_1.SemanticType.MATRIX
        ? 'children/row/children/cell/children/*'
        : 'children/line/children/*';
    const nodes = XpathUtil.evalXPath(xpath, node);
    const result = nodes.every(simpleCell_);
    return result ? [node] : [];
}
function isSmallVulgarFraction(node) {
    return (0, transformers_js_1.vulgarFractionSmall)(node, 20, 11) ? [node] : [];
}
function isUnitExpression(node) {
    return ((node.type === semantic_meaning_js_1.SemanticType.TEXT && node.role !== semantic_meaning_js_1.SemanticRole.LABEL) ||
        (node.type === semantic_meaning_js_1.SemanticType.PUNCTUATED &&
            node.role === semantic_meaning_js_1.SemanticRole.TEXT &&
            isNumber_(node.childNodes[0]) &&
            allTextLastContent_(node.childNodes.slice(1))) ||
        (node.type === semantic_meaning_js_1.SemanticType.IDENTIFIER &&
            node.role === semantic_meaning_js_1.SemanticRole.UNIT) ||
        (node.type === semantic_meaning_js_1.SemanticType.INFIXOP &&
            (node.role === semantic_meaning_js_1.SemanticRole.IMPLICIT || node.role === semantic_meaning_js_1.SemanticRole.UNIT)));
}
function allTextLastContent_(nodes) {
    for (let i = 0; i < nodes.length - 1; i++) {
        if (!(nodes[i].type === semantic_meaning_js_1.SemanticType.TEXT && nodes[i].textContent === '')) {
            return false;
        }
    }
    return nodes[nodes.length - 1].type === semantic_meaning_js_1.SemanticType.TEXT;
}
(0, semantic_annotations_js_1.register)(new semantic_annotator_js_1.SemanticAnnotator('clearspeak', 'unit', function (node) {
    return isUnitExpression(node) ? 'unit' : '';
}));
function ordinalExponent(node) {
    const num = parseInt(node.textContent, 10);
    return [
        span_js_1.Span.stringEmpty(isNaN(num)
            ? node.textContent
            : num > 10
                ? locale_js_1.LOCALE.NUMBERS.numericOrdinal(num)
                : locale_js_1.LOCALE.NUMBERS.wordOrdinal(num))
    ];
}
let NESTING_DEPTH = null;
function nestingDepth(node) {
    let count = 0;
    const fence = node.textContent;
    const index = node.getAttribute('role') === 'open' ? 0 : 1;
    let parent = node.parentNode;
    while (parent) {
        if (parent.tagName === semantic_meaning_js_1.SemanticType.FENCED &&
            parent.childNodes[0].childNodes[index].textContent === fence) {
            count++;
        }
        parent = parent.parentNode;
    }
    NESTING_DEPTH = count > 1 ? locale_js_1.LOCALE.NUMBERS.wordOrdinal(count) : '';
    return [span_js_1.Span.stringEmpty(NESTING_DEPTH)];
}
function matchingFences(node) {
    const sibling = node.previousSibling;
    let left, right;
    if (sibling) {
        left = sibling;
        right = node;
    }
    else {
        left = node;
        right = node.nextSibling;
    }
    if (!right) {
        return [];
    }
    return (0, semantic_attr_js_1.isMatchingFence)(left.textContent, right.textContent) ? [node] : [];
}
function insertNesting(text, correction) {
    if (!correction || !text) {
        return text;
    }
    const start = text.match(/^(open|close) /);
    if (!start) {
        return correction + ' ' + text;
    }
    return start[0] + correction + ' ' + text.substring(start[0].length);
}
grammar_js_1.Grammar.getInstance().setCorrection('insertNesting', insertNesting);
function fencedArguments(node) {
    const content = DomUtil.toArray(node.parentNode.childNodes);
    const children = XpathUtil.evalXPath('../../children/*', node);
    const index = content.indexOf(node);
    return fencedFactor_(children[index]) || fencedFactor_(children[index + 1])
        ? [node]
        : [];
}
function simpleArguments(node) {
    const content = DomUtil.toArray(node.parentNode.childNodes);
    const children = XpathUtil.evalXPath('../../children/*', node);
    const index = content.indexOf(node);
    return simpleFactor_(children[index]) &&
        children[index + 1] &&
        (simpleFactor_(children[index + 1]) ||
            children[index + 1].tagName === semantic_meaning_js_1.SemanticType.ROOT ||
            children[index + 1].tagName === semantic_meaning_js_1.SemanticType.SQRT ||
            (children[index + 1].tagName === semantic_meaning_js_1.SemanticType.SUPERSCRIPT &&
                children[index + 1].childNodes[0].childNodes[0] &&
                (children[index + 1].childNodes[0].childNodes[0]
                    .tagName === semantic_meaning_js_1.SemanticType.NUMBER ||
                    children[index + 1].childNodes[0].childNodes[0]
                        .tagName === semantic_meaning_js_1.SemanticType.IDENTIFIER) &&
                (children[index + 1].childNodes[0].childNodes[1].textContent === '2' ||
                    children[index + 1].childNodes[0].childNodes[1].textContent === '3')))
        ? [node]
        : [];
}
function simpleFactor_(node) {
    return (!!node &&
        (node.tagName === semantic_meaning_js_1.SemanticType.NUMBER ||
            node.tagName === semantic_meaning_js_1.SemanticType.IDENTIFIER ||
            node.tagName === semantic_meaning_js_1.SemanticType.FUNCTION ||
            node.tagName === semantic_meaning_js_1.SemanticType.APPL ||
            node.tagName === semantic_meaning_js_1.SemanticType.FRACTION));
}
function fencedFactor_(node) {
    return (node &&
        (node.tagName === semantic_meaning_js_1.SemanticType.FENCED ||
            (node.hasAttribute('role') &&
                node.getAttribute('role') === semantic_meaning_js_1.SemanticRole.LEFTRIGHT) ||
            layoutFactor_(node)));
}
function layoutFactor_(node) {
    return (!!node &&
        (node.tagName === semantic_meaning_js_1.SemanticType.MATRIX ||
            node.tagName === semantic_meaning_js_1.SemanticType.VECTOR));
}
function wordOrdinal(node) {
    return [
        span_js_1.Span.stringEmpty(locale_js_1.LOCALE.NUMBERS.wordOrdinal(parseInt(node.textContent, 10)))
    ];
}
