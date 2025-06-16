"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.openingFraction = openingFraction;
exports.closingFraction = closingFraction;
exports.overFraction = overFraction;
exports.overBevelledFraction = overBevelledFraction;
exports.hyperFractionBoundary = hyperFractionBoundary;
exports.openingRadical = openingRadical;
exports.closingRadical = closingRadical;
exports.indexRadical = indexRadical;
exports.relationIterator = relationIterator;
exports.implicitIterator = implicitIterator;
exports.contentIterator = contentIterator;
const auditory_description_js_1 = require("../audio/auditory_description.js");
const span_js_1 = require("../audio/span.js");
const DomUtil = require("../common/dom_util.js");
const XpathUtil = require("../common/xpath_util.js");
const grammar_js_1 = require("../rule_engine/grammar.js");
const engine_js_1 = require("../common/engine.js");
const semantic_annotations_js_1 = require("../semantic_tree/semantic_annotations.js");
const semantic_annotator_js_1 = require("../semantic_tree/semantic_annotator.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const locale_js_1 = require("../l10n/locale.js");
const MathspeakUtil = require("./mathspeak_util.js");
const store_util_js_1 = require("../rule_engine/store_util.js");
function openingFraction(node) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    return span_js_1.Span.singleton(new Array(depth).join(locale_js_1.LOCALE.MESSAGES.MS.FRACTION_REPEAT) +
        locale_js_1.LOCALE.MESSAGES.MS.FRACTION_START);
}
function closingFraction(node) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    return span_js_1.Span.singleton(new Array(depth).join(locale_js_1.LOCALE.MESSAGES.MS.FRACTION_REPEAT) +
        locale_js_1.LOCALE.MESSAGES.MS.FRACTION_END);
}
function overFraction(node) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    return span_js_1.Span.singleton(new Array(depth).join(locale_js_1.LOCALE.MESSAGES.MS.FRACTION_REPEAT) +
        locale_js_1.LOCALE.MESSAGES.MS.FRACTION_OVER);
}
function overBevelledFraction(node) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    return span_js_1.Span.singleton(new Array(depth).join(locale_js_1.LOCALE.MESSAGES.MS.FRACTION_REPEAT) +
        '⠸' +
        locale_js_1.LOCALE.MESSAGES.MS.FRACTION_OVER);
}
function hyperFractionBoundary(node) {
    return locale_js_1.LOCALE.MESSAGES.regexp.HYPER ===
        MathspeakUtil.fractionNestingDepth(node).toString()
        ? [node]
        : [];
}
function nestedRadical(node, postfix) {
    const depth = radicalNestingDepth(node);
    return span_js_1.Span.singleton(depth === 1
        ? postfix
        : new Array(depth).join(locale_js_1.LOCALE.MESSAGES.MS.NESTED) + postfix);
}
function radicalNestingDepth(node, opt_depth) {
    const depth = opt_depth || 0;
    if (!node.parentNode) {
        return depth;
    }
    return radicalNestingDepth(node.parentNode, node.tagName === 'root' || node.tagName === 'sqrt' ? depth + 1 : depth);
}
function openingRadical(node) {
    return nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.STARTROOT);
}
function closingRadical(node) {
    return nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.ENDROOT);
}
function indexRadical(node) {
    return nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.ROOTINDEX);
}
function enlargeFence(text) {
    const start = '⠠';
    if (text.length === 1) {
        return start + text;
    }
    const neut = '⠳';
    const split = text.split('');
    if (split.every(function (x) {
        return x === neut;
    })) {
        return start + split.join(start);
    }
    return text.slice(0, -1) + start + text.slice(-1);
}
grammar_js_1.Grammar.getInstance().setCorrection('enlargeFence', enlargeFence);
const NUMBER_PROPAGATORS = [
    semantic_meaning_js_1.SemanticType.MULTIREL,
    semantic_meaning_js_1.SemanticType.RELSEQ,
    semantic_meaning_js_1.SemanticType.APPL,
    semantic_meaning_js_1.SemanticType.ROW,
    semantic_meaning_js_1.SemanticType.LINE
];
const NUMBER_INHIBITORS = [
    semantic_meaning_js_1.SemanticType.SUBSCRIPT,
    semantic_meaning_js_1.SemanticType.SUPERSCRIPT,
    semantic_meaning_js_1.SemanticType.OVERSCORE,
    semantic_meaning_js_1.SemanticType.UNDERSCORE
];
function checkParent(node, info) {
    const parent = node.parent;
    if (!parent) {
        return false;
    }
    const type = parent.type;
    if (NUMBER_PROPAGATORS.indexOf(type) !== -1 ||
        (type === semantic_meaning_js_1.SemanticType.PREFIXOP &&
            parent.role === semantic_meaning_js_1.SemanticRole.NEGATIVE &&
            !info.script &&
            !info.enclosed) ||
        (type === semantic_meaning_js_1.SemanticType.PREFIXOP &&
            parent.role === semantic_meaning_js_1.SemanticRole.GEOMETRY)) {
        return true;
    }
    if (type === semantic_meaning_js_1.SemanticType.PUNCTUATED) {
        if (!info.enclosed || parent.role === semantic_meaning_js_1.SemanticRole.TEXT) {
            return true;
        }
    }
    return false;
}
function propagateNumber(node, info) {
    if (!node.childNodes.length) {
        if (checkParent(node, info)) {
            info.number = true;
            info.script = false;
            info.enclosed = false;
        }
        return [
            info['number'] ? 'number' : '',
            { number: false, enclosed: info.enclosed, script: info.script }
        ];
    }
    if (NUMBER_INHIBITORS.indexOf(node.type) !== -1) {
        info.script = true;
    }
    if (node.type === semantic_meaning_js_1.SemanticType.FENCED) {
        info.number = false;
        info.enclosed = true;
        return ['', info];
    }
    if (node.type === semantic_meaning_js_1.SemanticType.PREFIXOP &&
        node.role !== semantic_meaning_js_1.SemanticRole.GEOMETRY &&
        node.role !== semantic_meaning_js_1.SemanticRole.NEGATIVE) {
        info.number = false;
        return ['', info];
    }
    if (checkParent(node, info)) {
        info.number = true;
        info.enclosed = false;
    }
    return ['', info];
}
(0, semantic_annotations_js_1.register)(new semantic_annotator_js_1.SemanticVisitor('nemeth', 'number', propagateNumber, { number: true }));
function annotateDepth(node) {
    if (!node.parent) {
        return [1];
    }
    const depth = parseInt(node.parent.annotation['depth'][0]);
    return [depth + 1];
}
(0, semantic_annotations_js_1.register)(new semantic_annotator_js_1.SemanticVisitor('depth', 'depth', annotateDepth));
(0, semantic_annotations_js_1.activate)('depth', 'depth');
function relationIterator(nodes, context) {
    var _a;
    const childNodes = nodes.slice(0);
    let first = true;
    const parentNode = nodes[0].parentNode.parentNode;
    const match = (_a = parentNode.getAttribute('annotation')) === null || _a === void 0 ? void 0 : _a.match(/depth:(\d+)/);
    const depth = match ? match[1] : '';
    let contentNodes;
    if (nodes.length > 0) {
        contentNodes = XpathUtil.evalXPath('./content/*', parentNode);
    }
    else {
        contentNodes = [];
    }
    return function () {
        const content = contentNodes.shift();
        const leftChild = childNodes.shift();
        const rightChild = childNodes[0];
        const contextDescr = context
            ? [auditory_description_js_1.AuditoryDescription.create({ text: context }, { translate: true })]
            : [];
        if (!content) {
            return contextDescr;
        }
        const base = leftChild
            ? MathspeakUtil.nestedSubSuper(leftChild, '', {
                sup: locale_js_1.LOCALE.MESSAGES.MS.SUPER,
                sub: locale_js_1.LOCALE.MESSAGES.MS.SUB
            })
            : '';
        const left = (leftChild && DomUtil.tagName(leftChild) !== 'EMPTY') ||
            (first && parentNode && parentNode.previousSibling)
            ? [
                auditory_description_js_1.AuditoryDescription.create({ text: locale_js_1.LOCALE.MESSAGES.regexp.SPACE + base }, {})
            ]
            : [];
        const right = (rightChild && DomUtil.tagName(rightChild) !== 'EMPTY') ||
            (!contentNodes.length && parentNode && parentNode.nextSibling)
            ? [
                auditory_description_js_1.AuditoryDescription.create({ text: locale_js_1.LOCALE.MESSAGES.regexp.SPACE }, {})
            ]
            : [];
        const descrs = engine_js_1.Engine.evaluateNode(content);
        descrs.unshift(new auditory_description_js_1.AuditoryDescription({ text: '', layout: `beginrel${depth}` }));
        descrs.push(new auditory_description_js_1.AuditoryDescription({ text: '', layout: `endrel${depth}` }));
        first = false;
        return contextDescr.concat(left, descrs, right);
    };
}
function implicitIterator(nodes, context) {
    const childNodes = nodes.slice(0);
    let contentNodes;
    if (nodes.length > 0) {
        contentNodes = XpathUtil.evalXPath('../../content/*', nodes[0]);
    }
    else {
        contentNodes = [];
    }
    return function () {
        const leftChild = childNodes.shift();
        const rightChild = childNodes[0];
        const content = contentNodes.shift();
        const contextDescr = context
            ? [auditory_description_js_1.AuditoryDescription.create({ text: context }, { translate: true })]
            : [];
        if (!content) {
            return contextDescr;
        }
        const left = leftChild && DomUtil.tagName(leftChild) === 'NUMBER';
        const right = rightChild && DomUtil.tagName(rightChild) === 'NUMBER';
        return contextDescr.concat(left && right && content.getAttribute('role') === semantic_meaning_js_1.SemanticRole.SPACE
            ? [
                auditory_description_js_1.AuditoryDescription.create({ text: locale_js_1.LOCALE.MESSAGES.regexp.SPACE }, {})
            ]
            : []);
    };
}
function ignoreEnglish(text) {
    return (0, grammar_js_1.correctFont)(text, locale_js_1.LOCALE.ALPHABETS.languagePrefix.english);
}
grammar_js_1.Grammar.getInstance().setCorrection('ignoreEnglish', ignoreEnglish);
function contentIterator(nodes, context) {
    var _a;
    const func = (0, store_util_js_1.contentIterator)(nodes, context);
    const parentNode = nodes[0].parentNode.parentNode;
    const match = (_a = parentNode.getAttribute('annotation')) === null || _a === void 0 ? void 0 : _a.match(/depth:(\d+)/);
    const depth = match ? match[1] : '';
    return function () {
        const descrs = func();
        descrs.unshift(new auditory_description_js_1.AuditoryDescription({ text: '', layout: `beginrel${depth}` }));
        descrs.push(new auditory_description_js_1.AuditoryDescription({ text: '', layout: `endrel${depth}` }));
        return descrs;
    };
}
function literal(text) {
    const evalStr = (e) => engine_js_1.Engine.getInstance().evaluator(e, engine_js_1.Engine.getInstance().dynamicCstr);
    return Array.from(text).map(evalStr).join('');
}
grammar_js_1.Grammar.getInstance().setCorrection('literal', literal);
