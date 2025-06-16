import { AuditoryDescription } from '../audio/auditory_description.js';
import * as XpathUtil from '../common/xpath_util.js';
import { LOCALE } from '../l10n/locale.js';
import { SemanticType } from '../semantic_tree/semantic_meaning.js';
export function unitMultipliers(nodes, _context) {
    const children = nodes;
    let counter = 0;
    return function () {
        const descr = AuditoryDescription.create({
            text: rightMostUnit(children[counter]) &&
                leftMostUnit(children[counter + 1])
                ? LOCALE.MESSAGES.unitTimes
                : ''
        }, {});
        counter++;
        return [descr];
    };
}
const SCRIPT_ELEMENTS = [
    SemanticType.SUPERSCRIPT,
    SemanticType.SUBSCRIPT,
    SemanticType.OVERSCORE,
    SemanticType.UNDERSCORE
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
export function oneLeft(node) {
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
