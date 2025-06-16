"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.nestedFraction = nestedFraction;
exports.openingFractionVerbose = openingFractionVerbose;
exports.closingFractionVerbose = closingFractionVerbose;
exports.openingFractionBrief = openingFractionBrief;
exports.closingFractionBrief = closingFractionBrief;
exports.openingFractionSbrief = openingFractionSbrief;
exports.closingFractionSbrief = closingFractionSbrief;
exports.overFractionSbrief = overFractionSbrief;
exports.isSimpleIndex = isSimpleIndex;
exports.nestedRadical = nestedRadical;
exports.openingRadicalVerbose = openingRadicalVerbose;
exports.closingRadicalVerbose = closingRadicalVerbose;
exports.openingRadicalBrief = openingRadicalBrief;
exports.closingRadicalBrief = closingRadicalBrief;
exports.openingRadicalSbrief = openingRadicalSbrief;
exports.getRootIndex = getRootIndex;
exports.indexRadical = indexRadical;
exports.indexRadicalVerbose = indexRadicalVerbose;
exports.indexRadicalBrief = indexRadicalBrief;
exports.indexRadicalSbrief = indexRadicalSbrief;
exports.ordinalConversion = ordinalConversion;
exports.decreasedOrdinalConversion = decreasedOrdinalConversion;
exports.listOrdinalConversion = listOrdinalConversion;
exports.checkDepth = checkDepth;
exports.getDepthValue = getDepthValue;
const span_js_1 = require("../audio/span.js");
const MathspeakUtil = require("./mathspeak_util.js");
const locale_js_1 = require("../l10n/locale.js");
const XpathUtil = require("../common/xpath_util.js");
function nestedFraction(node, expr, opt_end) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    const annotation = [...Array(depth)].map((_x) => expr);
    if (opt_end) {
        annotation.unshift(opt_end);
    }
    return annotation.join(locale_js_1.LOCALE.MESSAGES.regexp.JOINER_FRAC);
}
function openingFractionVerbose(node) {
    return span_js_1.Span.singleton(nestedFraction(node, locale_js_1.LOCALE.MESSAGES.MS.START, locale_js_1.LOCALE.MESSAGES.MS.FRAC_V));
}
function closingFractionVerbose(node) {
    return span_js_1.Span.singleton(nestedFraction(node, locale_js_1.LOCALE.MESSAGES.MS.END, locale_js_1.LOCALE.MESSAGES.MS.FRAC_V));
}
function openingFractionBrief(node) {
    return span_js_1.Span.singleton(nestedFraction(node, locale_js_1.LOCALE.MESSAGES.MS.START, locale_js_1.LOCALE.MESSAGES.MS.FRAC_B));
}
function closingFractionBrief(node) {
    return span_js_1.Span.singleton(nestedFraction(node, locale_js_1.LOCALE.MESSAGES.MS.END, locale_js_1.LOCALE.MESSAGES.MS.FRAC_B));
}
function openingFractionSbrief(node) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    if (depth === 1) {
        return span_js_1.Span.singleton(locale_js_1.LOCALE.MESSAGES.MS.FRAC_S);
    }
    return span_js_1.Span.singleton(locale_js_1.LOCALE.FUNCTIONS.combineNestedFraction(locale_js_1.LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), locale_js_1.LOCALE.MESSAGES.MS.NEST_FRAC, locale_js_1.LOCALE.MESSAGES.MS.FRAC_S));
}
function closingFractionSbrief(node) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    if (depth === 1) {
        return span_js_1.Span.singleton(locale_js_1.LOCALE.MESSAGES.MS.ENDFRAC);
    }
    return span_js_1.Span.singleton(locale_js_1.LOCALE.FUNCTIONS.combineNestedFraction(locale_js_1.LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), locale_js_1.LOCALE.MESSAGES.MS.NEST_FRAC, locale_js_1.LOCALE.MESSAGES.MS.ENDFRAC));
}
function overFractionSbrief(node) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    if (depth === 1) {
        return span_js_1.Span.singleton(locale_js_1.LOCALE.MESSAGES.MS.FRAC_OVER);
    }
    return span_js_1.Span.singleton(locale_js_1.LOCALE.FUNCTIONS.combineNestedFraction(locale_js_1.LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), locale_js_1.LOCALE.MESSAGES.MS.NEST_FRAC, locale_js_1.LOCALE.MESSAGES.MS.FRAC_OVER));
}
function isSimpleIndex(node) {
    const index = XpathUtil.evalXPath('children/*[1]', node)[0]
        .toString()
        .match(/[^>⁢>]+<\/[^>]*>/g);
    return index.length === 1 ? [node] : [];
}
function nestedRadical(node, prefix, postfix) {
    const depth = MathspeakUtil.radicalNestingDepth(node);
    if (depth === 1)
        return postfix;
    return locale_js_1.LOCALE.FUNCTIONS.combineNestedRadical(locale_js_1.LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), prefix, postfix);
}
function openingRadicalVerbose(node) {
    return span_js_1.Span.singleton(nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.NESTED, locale_js_1.LOCALE.MESSAGES.MS.STARTROOT));
}
function closingRadicalVerbose(node) {
    return span_js_1.Span.singleton(nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.NESTED, locale_js_1.LOCALE.MESSAGES.MS.ENDROOT));
}
function openingRadicalBrief(node) {
    return span_js_1.Span.singleton(nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.NEST_ROOT, locale_js_1.LOCALE.MESSAGES.MS.STARTROOT));
}
function closingRadicalBrief(node) {
    return span_js_1.Span.singleton(nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.NEST_ROOT, locale_js_1.LOCALE.MESSAGES.MS.ENDROOT));
}
function openingRadicalSbrief(node) {
    return span_js_1.Span.singleton(nestedRadical(node, locale_js_1.LOCALE.MESSAGES.MS.NEST_ROOT, locale_js_1.LOCALE.MESSAGES.MS.ROOT));
}
function getRootIndex(node) {
    const content = XpathUtil.evalXPath('children/*[1]', node)[0].textContent.trim();
    return locale_js_1.LOCALE.MESSAGES.MSroots[content] || content + '제곱근';
}
function indexRadical(node, postfix) {
    const index = getRootIndex(node);
    return index ? index : postfix;
}
function indexRadicalVerbose(node) {
    return span_js_1.Span.singleton(indexRadical(node, locale_js_1.LOCALE.MESSAGES.MS.ROOTINDEX));
}
function indexRadicalBrief(node) {
    return span_js_1.Span.singleton(indexRadical(node, locale_js_1.LOCALE.MESSAGES.MS.ROOTINDEX));
}
function indexRadicalSbrief(node) {
    return span_js_1.Span.singleton(indexRadical(node, locale_js_1.LOCALE.MESSAGES.MS.INDEX));
}
function ordinalConversion(node) {
    const children = XpathUtil.evalXPath('children/*', node);
    return span_js_1.Span.singleton(locale_js_1.LOCALE.NUMBERS.wordOrdinal(children.length));
}
function decreasedOrdinalConversion(node) {
    const children = XpathUtil.evalXPath('children/*', node);
    return span_js_1.Span.singleton(locale_js_1.LOCALE.NUMBERS.wordOrdinal(children.length - 1));
}
function listOrdinalConversion(node) {
    const children = XpathUtil.evalXPath('children/*', node);
    const content = XpathUtil.evalXPath('content/*', node);
    return span_js_1.Span.singleton(locale_js_1.LOCALE.NUMBERS.wordOrdinal(children.length - content.length));
}
function checkDepth(node) {
    const roleList = [];
    const depth = getDepthValue(node, roleList);
    return depth > 3 ? [] : [node];
}
function getDepthValue(node, roleList) {
    const role = node.getAttribute('role');
    const index = roleList.indexOf(role) > -1;
    if (!index) {
        roleList.push(role);
    }
    const children = XpathUtil.evalXPath('children/*', node);
    let max = 0, cur = 0;
    if (children.length) {
        children.forEach((child) => {
            cur = getDepthValue(child, roleList);
            max = cur > max ? cur : max;
        });
        return max + 1;
    }
    return 0;
}
