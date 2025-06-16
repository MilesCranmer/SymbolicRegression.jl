import { Span } from '../audio/span.js';
import * as MathspeakUtil from './mathspeak_util.js';
import { LOCALE } from '../l10n/locale.js';
import * as XpathUtil from '../common/xpath_util.js';
export function nestedFraction(node, expr, opt_end) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    const annotation = [...Array(depth)].map((_x) => expr);
    if (opt_end) {
        annotation.unshift(opt_end);
    }
    return annotation.join(LOCALE.MESSAGES.regexp.JOINER_FRAC);
}
export function openingFractionVerbose(node) {
    return Span.singleton(nestedFraction(node, LOCALE.MESSAGES.MS.START, LOCALE.MESSAGES.MS.FRAC_V));
}
export function closingFractionVerbose(node) {
    return Span.singleton(nestedFraction(node, LOCALE.MESSAGES.MS.END, LOCALE.MESSAGES.MS.FRAC_V));
}
export function openingFractionBrief(node) {
    return Span.singleton(nestedFraction(node, LOCALE.MESSAGES.MS.START, LOCALE.MESSAGES.MS.FRAC_B));
}
export function closingFractionBrief(node) {
    return Span.singleton(nestedFraction(node, LOCALE.MESSAGES.MS.END, LOCALE.MESSAGES.MS.FRAC_B));
}
export function openingFractionSbrief(node) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    if (depth === 1) {
        return Span.singleton(LOCALE.MESSAGES.MS.FRAC_S);
    }
    return Span.singleton(LOCALE.FUNCTIONS.combineNestedFraction(LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), LOCALE.MESSAGES.MS.NEST_FRAC, LOCALE.MESSAGES.MS.FRAC_S));
}
export function closingFractionSbrief(node) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    if (depth === 1) {
        return Span.singleton(LOCALE.MESSAGES.MS.ENDFRAC);
    }
    return Span.singleton(LOCALE.FUNCTIONS.combineNestedFraction(LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), LOCALE.MESSAGES.MS.NEST_FRAC, LOCALE.MESSAGES.MS.ENDFRAC));
}
export function overFractionSbrief(node) {
    const depth = MathspeakUtil.fractionNestingDepth(node);
    if (depth === 1) {
        return Span.singleton(LOCALE.MESSAGES.MS.FRAC_OVER);
    }
    return Span.singleton(LOCALE.FUNCTIONS.combineNestedFraction(LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), LOCALE.MESSAGES.MS.NEST_FRAC, LOCALE.MESSAGES.MS.FRAC_OVER));
}
export function isSimpleIndex(node) {
    const index = XpathUtil.evalXPath('children/*[1]', node)[0]
        .toString()
        .match(/[^>⁢>]+<\/[^>]*>/g);
    return index.length === 1 ? [node] : [];
}
export function nestedRadical(node, prefix, postfix) {
    const depth = MathspeakUtil.radicalNestingDepth(node);
    if (depth === 1)
        return postfix;
    return LOCALE.FUNCTIONS.combineNestedRadical(LOCALE.FUNCTIONS.radicalNestDepth(depth - 1), prefix, postfix);
}
export function openingRadicalVerbose(node) {
    return Span.singleton(nestedRadical(node, LOCALE.MESSAGES.MS.NESTED, LOCALE.MESSAGES.MS.STARTROOT));
}
export function closingRadicalVerbose(node) {
    return Span.singleton(nestedRadical(node, LOCALE.MESSAGES.MS.NESTED, LOCALE.MESSAGES.MS.ENDROOT));
}
export function openingRadicalBrief(node) {
    return Span.singleton(nestedRadical(node, LOCALE.MESSAGES.MS.NEST_ROOT, LOCALE.MESSAGES.MS.STARTROOT));
}
export function closingRadicalBrief(node) {
    return Span.singleton(nestedRadical(node, LOCALE.MESSAGES.MS.NEST_ROOT, LOCALE.MESSAGES.MS.ENDROOT));
}
export function openingRadicalSbrief(node) {
    return Span.singleton(nestedRadical(node, LOCALE.MESSAGES.MS.NEST_ROOT, LOCALE.MESSAGES.MS.ROOT));
}
export function getRootIndex(node) {
    const content = XpathUtil.evalXPath('children/*[1]', node)[0].textContent.trim();
    return LOCALE.MESSAGES.MSroots[content] || content + '제곱근';
}
export function indexRadical(node, postfix) {
    const index = getRootIndex(node);
    return index ? index : postfix;
}
export function indexRadicalVerbose(node) {
    return Span.singleton(indexRadical(node, LOCALE.MESSAGES.MS.ROOTINDEX));
}
export function indexRadicalBrief(node) {
    return Span.singleton(indexRadical(node, LOCALE.MESSAGES.MS.ROOTINDEX));
}
export function indexRadicalSbrief(node) {
    return Span.singleton(indexRadical(node, LOCALE.MESSAGES.MS.INDEX));
}
export function ordinalConversion(node) {
    const children = XpathUtil.evalXPath('children/*', node);
    return Span.singleton(LOCALE.NUMBERS.wordOrdinal(children.length));
}
export function decreasedOrdinalConversion(node) {
    const children = XpathUtil.evalXPath('children/*', node);
    return Span.singleton(LOCALE.NUMBERS.wordOrdinal(children.length - 1));
}
export function listOrdinalConversion(node) {
    const children = XpathUtil.evalXPath('children/*', node);
    const content = XpathUtil.evalXPath('content/*', node);
    return Span.singleton(LOCALE.NUMBERS.wordOrdinal(children.length - content.length));
}
export function checkDepth(node) {
    const roleList = [];
    const depth = getDepthValue(node, roleList);
    return depth > 3 ? [] : [node];
}
export function getDepthValue(node, roleList) {
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
