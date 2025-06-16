import { Debugger } from '../common/debugger.js';
import * as DomUtil from '../common/dom_util.js';
import { Engine } from '../common/engine.js';
import { NamedSymbol } from '../semantic_tree/semantic_attr.js';
import { SemanticRole, SemanticType } from '../semantic_tree/semantic_meaning.js';
import { SemanticHeuristics } from '../semantic_tree/semantic_heuristic_factory.js';
import { SemanticSkeleton } from '../semantic_tree/semantic_skeleton.js';
import * as SemanticUtil from '../semantic_tree/semantic_util.js';
import { MMLTAGS } from '../semantic_tree/semantic_util.js';
import * as EnrichAttr from './enrich_attr.js';
import { getCase } from './enrich_case.js';
const SETTINGS = {
    collapsed: true,
    implicit: true,
    wiki: true
};
const IDS = new Map();
export function enrich(mml, semantic) {
    IDS.clear();
    const oldMml = DomUtil.cloneNode(mml);
    walkTree(semantic.root);
    if (Engine.getInstance().structure) {
        mml.setAttribute(EnrichAttr.Attribute.STRUCTURE, SemanticSkeleton.fromStructure(mml, semantic).toString());
    }
    Debugger.getInstance().generateOutput(() => [
        formattedOutput(oldMml, 'Original MathML', SETTINGS.wiki),
        formattedOutput(semantic, 'Semantic Tree', SETTINGS.wiki),
        formattedOutput(mml, 'Semantically enriched MathML', SETTINGS.wiki)
    ]);
    return mml;
}
export function walkTree(semantic) {
    Debugger.getInstance().output('WALKING START: ' + semantic.toString());
    const specialCase = getCase(semantic);
    let newNode;
    if (specialCase) {
        newNode = specialCase.getMathml();
        Debugger.getInstance().output('WALKING END: ' + semantic.toString());
        return ascendNewNode(newNode);
    }
    if (semantic.mathml.length === 1) {
        Debugger.getInstance().output('Walktree Case 0');
        if (!semantic.childNodes.length) {
            Debugger.getInstance().output('Walktree Case 0.1');
            newNode = semantic.mathml[0];
            EnrichAttr.setAttributes(newNode, semantic);
            Debugger.getInstance().output('WALKING END: ' + semantic.toString());
            return ascendNewNode(newNode);
        }
        const fchild = semantic.childNodes[0];
        if (semantic.childNodes.length === 1 &&
            fchild.type === SemanticType.EMPTY) {
            Debugger.getInstance().output('Walktree Case 0.2');
            newNode = semantic.mathml[0];
            EnrichAttr.setAttributes(newNode, semantic);
            newNode.appendChild(walkTree(fchild));
            Debugger.getInstance().output('WALKING END: ' + semantic.toString());
            return ascendNewNode(newNode);
        }
        semantic.childNodes.forEach((child) => {
            if (!child.mathml.length) {
                child.mathml = [createInvisibleOperator(child)];
            }
        });
    }
    const newContent = semantic.contentNodes.map(cloneContentNode);
    setOperatorAttribute(semantic, newContent);
    const newChildren = semantic.childNodes.map(walkTree);
    const childrenList = SemanticSkeleton.combineContentChildren(semantic.type, semantic.role, newContent, newChildren);
    newNode = semantic.mathmlTree;
    if (newNode === null) {
        Debugger.getInstance().output('Walktree Case 1');
        newNode = introduceNewLayer(childrenList, semantic);
    }
    else {
        const attached = attachedElement(childrenList);
        Debugger.getInstance().output('Walktree Case 2');
        if (attached) {
            Debugger.getInstance().output('Walktree Case 2.1');
            newNode = parentNode(attached);
        }
        else {
            Debugger.getInstance().output('Walktree Case 2.2');
            newNode = getInnerNode(newNode);
        }
    }
    newNode = rewriteMfenced(newNode);
    mergeChildren(newNode, childrenList, semantic);
    if (!IDS.has(semantic.id)) {
        IDS.set(semantic.id, true);
        EnrichAttr.setAttributes(newNode, semantic);
    }
    Debugger.getInstance().output('WALKING END: ' + semantic.toString());
    return ascendNewNode(newNode);
}
export function introduceNewLayer(children, semantic) {
    const lca = mathmlLca(children);
    let newNode = lca.node;
    const info = lca.type;
    if (info !== lcaType.VALID ||
        !SemanticUtil.hasEmptyTag(newNode) ||
        (!newNode.parentNode && semantic.parent)) {
        Debugger.getInstance().output('Walktree Case 1.1');
        newNode = EnrichAttr.addMrow();
        if (info === lcaType.PRUNED) {
            Debugger.getInstance().output('Walktree Case 1.1.0');
            newNode = introduceLayerAboveLca(newNode, lca.node, children);
        }
        else if (children[0]) {
            Debugger.getInstance().output('Walktree Case 1.1.1');
            const node = attachedElement(children);
            if (node) {
                const oldChildren = childrenSubset(parentNode(node), children);
                DomUtil.replaceNode(node, newNode);
                oldChildren.forEach(function (x) {
                    newNode.appendChild(x);
                });
            }
            else {
                moveSemanticAttributes(newNode, children[0]);
                newNode = children[0];
            }
        }
    }
    if (!semantic.mathmlTree) {
        semantic.mathmlTree = newNode;
    }
    return newNode;
}
function introduceLayerAboveLca(mrow, lca, children) {
    let innerNode = descendNode(lca);
    if (SemanticUtil.hasMathTag(innerNode)) {
        Debugger.getInstance().output('Walktree Case 1.1.0.0');
        moveSemanticAttributes(innerNode, mrow);
        DomUtil.toArray(innerNode.childNodes).forEach(function (x) {
            mrow.appendChild(x);
        });
        const auxNode = mrow;
        mrow = innerNode;
        innerNode = auxNode;
    }
    const index = children.indexOf(lca);
    children[index] = innerNode;
    DomUtil.replaceNode(innerNode, mrow);
    mrow.appendChild(innerNode);
    children.forEach(function (x) {
        mrow.appendChild(x);
    });
    return mrow;
}
function moveSemanticAttributes(oldNode, newNode) {
    for (const attr of EnrichAttr.EnrichAttributes) {
        if (oldNode.hasAttribute(attr)) {
            newNode.setAttribute(attr, oldNode.getAttribute(attr));
            oldNode.removeAttribute(attr);
        }
    }
}
function childrenSubset(node, newChildren) {
    const oldChildren = DomUtil.toArray(node.childNodes);
    let leftIndex = +Infinity;
    let rightIndex = -Infinity;
    newChildren.forEach(function (child) {
        const index = oldChildren.indexOf(child);
        if (index !== -1) {
            leftIndex = Math.min(leftIndex, index);
            rightIndex = Math.max(rightIndex, index);
        }
    });
    return oldChildren.slice(leftIndex, rightIndex + 1);
}
function collateChildNodes(node, children, semantic) {
    const oldChildren = [];
    let newChildren = DomUtil.toArray(node.childNodes);
    let notFirst = false;
    while (newChildren.length) {
        const child = newChildren.shift();
        if (child.hasAttribute(EnrichAttr.Attribute.TYPE)) {
            oldChildren.push(child);
            continue;
        }
        const collect = collectChildNodes(child, children);
        if (collect.length === 0) {
            continue;
        }
        if (collect.length === 1) {
            oldChildren.push(child);
            continue;
        }
        if (notFirst) {
            child.setAttribute('AuxiliaryImplicit', true);
        }
        else {
            notFirst = true;
        }
        newChildren = collect.concat(newChildren);
    }
    const rear = [];
    const semChildren = semantic.childNodes.map(function (x) {
        return x.mathmlTree;
    });
    while (semChildren.length) {
        const schild = semChildren.pop();
        if (!schild) {
            continue;
        }
        if (oldChildren.indexOf(schild) !== -1) {
            break;
        }
        if (children.indexOf(schild) !== -1) {
            rear.unshift(schild);
        }
    }
    return oldChildren.concat(rear);
}
function collectChildNodes(node, children) {
    const collect = [];
    let newChildren = DomUtil.toArray(node.childNodes);
    while (newChildren.length) {
        const child = newChildren.shift();
        if (child.nodeType !== DomUtil.NodeType.ELEMENT_NODE) {
            continue;
        }
        if (child.hasAttribute(EnrichAttr.Attribute.TYPE) ||
            children.indexOf(child) !== -1) {
            collect.push(child);
            continue;
        }
        newChildren = DomUtil.toArray(child.childNodes).concat(newChildren);
    }
    return collect;
}
function mergeChildren(node, newChildren, semantic) {
    if (!newChildren.length)
        return;
    if (newChildren.length === 1 && node === newChildren[0])
        return;
    const oldChildren = semantic.role === SemanticRole.IMPLICIT &&
        SemanticHeuristics.flags.combine_juxtaposition
        ? collateChildNodes(node, newChildren, semantic)
        : DomUtil.toArray(node.childNodes);
    if (!oldChildren.length) {
        newChildren.forEach(function (x) {
            node.appendChild(x);
        });
        return;
    }
    let oldCounter = 0;
    while (newChildren.length) {
        const newChild = newChildren[0];
        if (oldChildren[oldCounter] === newChild ||
            functionApplication(oldChildren[oldCounter], newChild)) {
            newChildren.shift();
            oldCounter++;
            continue;
        }
        if (oldChildren[oldCounter] &&
            newChildren.indexOf(oldChildren[oldCounter]) === -1) {
            oldCounter++;
            continue;
        }
        if (isDescendant(newChild, node)) {
            newChildren.shift();
            continue;
        }
        const oldChild = oldChildren[oldCounter];
        if (!oldChild) {
            if (newChild.parentNode) {
                node = parentNode(newChild);
                newChildren.shift();
                continue;
            }
            const nextChild = newChildren[1];
            if (nextChild && nextChild.parentNode) {
                node = parentNode(nextChild);
                node.insertBefore(newChild, nextChild);
                newChildren.shift();
                newChildren.shift();
                continue;
            }
            node.insertBefore(newChild, null);
            newChildren.shift();
            continue;
        }
        insertNewChild(node, oldChild, newChild);
        newChildren.shift();
    }
}
function insertNewChild(node, oldChild, newChild) {
    let parent = oldChild;
    let next = parentNode(parent);
    while (next &&
        next.firstChild === parent &&
        !parent.hasAttribute('AuxiliaryImplicit') &&
        next !== node) {
        parent = next;
        next = parentNode(parent);
    }
    if (next) {
        next.insertBefore(newChild, parent);
        parent.removeAttribute('AuxiliaryImplicit');
    }
}
function isDescendant(child, node) {
    if (!child) {
        return false;
    }
    do {
        child = parentNode(child);
        if (child === node) {
            return true;
        }
    } while (child);
    return false;
}
function functionApplication(oldNode, newNode) {
    const appl = NamedSymbol.functionApplication;
    if (oldNode &&
        newNode &&
        oldNode.textContent &&
        newNode.textContent &&
        oldNode.textContent === appl &&
        newNode.textContent === appl &&
        newNode.getAttribute(EnrichAttr.Attribute.ADDED) === 'true') {
        for (let i = 0, attr; (attr = oldNode.attributes[i]); i++) {
            if (!newNode.hasAttribute(attr.nodeName)) {
                newNode.setAttribute(attr.nodeName, attr.nodeValue);
            }
        }
        DomUtil.replaceNode(oldNode, newNode);
        return true;
    }
    return false;
}
var lcaType;
(function (lcaType) {
    lcaType["VALID"] = "valid";
    lcaType["INVALID"] = "invalid";
    lcaType["PRUNED"] = "pruned";
})(lcaType || (lcaType = {}));
function mathmlLca(children) {
    const leftMost = attachedElement(children);
    if (!leftMost) {
        return { type: lcaType.INVALID, node: null };
    }
    const rightMost = attachedElement(children.slice().reverse());
    if (leftMost === rightMost) {
        return { type: lcaType.VALID, node: leftMost };
    }
    const leftPath = pathToRoot(leftMost);
    const newLeftPath = prunePath(leftPath, children);
    const rightPath = pathToRoot(rightMost, function (x) {
        return newLeftPath.indexOf(x) !== -1;
    });
    const lca = rightPath[0];
    const lIndex = newLeftPath.indexOf(lca);
    if (lIndex === -1) {
        return { type: lcaType.INVALID, node: null };
    }
    return {
        type: newLeftPath.length !== leftPath.length
            ? lcaType.PRUNED
            : validLca(newLeftPath[lIndex + 1], rightPath[1])
                ? lcaType.VALID
                : lcaType.INVALID,
        node: lca
    };
}
function prunePath(path, children) {
    let i = 0;
    while (path[i] && children.indexOf(path[i]) === -1) {
        i++;
    }
    return path.slice(0, i + 1);
}
function attachedElement(nodes) {
    let count = 0;
    let attached = null;
    while (!attached && count < nodes.length) {
        if (nodes[count].parentNode) {
            attached = nodes[count];
        }
        count++;
    }
    return attached;
}
function pathToRoot(node, opt_test) {
    const test = opt_test || ((_x) => false);
    const path = [node];
    while (!test(node) && !SemanticUtil.hasMathTag(node) && node.parentNode) {
        node = parentNode(node);
        path.unshift(node);
    }
    return path;
}
function validLca(left, right) {
    return !!(left && right && !left.previousSibling && !right.nextSibling);
}
export function ascendNewNode(newNode) {
    while (!SemanticUtil.hasMathTag(newNode) && unitChild(newNode)) {
        newNode = parentNode(newNode);
    }
    return newNode;
}
function descendNode(node) {
    const children = DomUtil.toArray(node.childNodes);
    if (!children) {
        return node;
    }
    const remainder = children.filter(function (child) {
        return (child.nodeType === DomUtil.NodeType.ELEMENT_NODE &&
            !SemanticUtil.hasIgnoreTag(child));
    });
    if (remainder.length === 1 &&
        SemanticUtil.hasEmptyTag(remainder[0]) &&
        !remainder[0].hasAttribute(EnrichAttr.Attribute.TYPE)) {
        return descendNode(remainder[0]);
    }
    return node;
}
function unitChild(node) {
    const parent = parentNode(node);
    if (!parent || !SemanticUtil.hasEmptyTag(parent)) {
        return false;
    }
    return DomUtil.toArray(parent.childNodes).every(function (child) {
        return child === node || isIgnorable(child);
    });
}
function isIgnorable(node) {
    if (node.nodeType !== DomUtil.NodeType.ELEMENT_NODE) {
        return true;
    }
    if (!node || SemanticUtil.hasIgnoreTag(node)) {
        return true;
    }
    const children = DomUtil.toArray(node.childNodes);
    if ((!SemanticUtil.hasEmptyTag(node) && children.length) ||
        SemanticUtil.hasDisplayTag(node) ||
        node.hasAttribute(EnrichAttr.Attribute.TYPE) ||
        SemanticUtil.isOrphanedGlyph(node)) {
        return false;
    }
    return DomUtil.toArray(node.childNodes).every(isIgnorable);
}
function parentNode(element) {
    return element.parentNode;
}
export function addCollapsedAttribute(node, collapsed) {
    const skeleton = new SemanticSkeleton(collapsed);
    node.setAttribute(EnrichAttr.Attribute.COLLAPSED, skeleton.toString());
}
export function cloneContentNode(content) {
    if (content.mathml.length) {
        return walkTree(content);
    }
    const clone = SETTINGS.implicit
        ? createInvisibleOperator(content)
        : EnrichAttr.addMrow();
    content.mathml = [clone];
    return clone;
}
export function rewriteMfenced(mml) {
    if (DomUtil.tagName(mml) !== MMLTAGS.MFENCED) {
        return mml;
    }
    const newNode = EnrichAttr.addMrow();
    for (let i = 0, attr; (attr = mml.attributes[i]); i++) {
        if (['open', 'close', 'separators'].indexOf(attr.name) === -1) {
            newNode.setAttribute(attr.name, attr.value);
        }
    }
    DomUtil.toArray(mml.childNodes).forEach(function (x) {
        newNode.appendChild(x);
    });
    DomUtil.replaceNode(mml, newNode);
    return newNode;
}
function createInvisibleOperator(operator) {
    const moNode = DomUtil.createElement('mo');
    const text = DomUtil.createTextNode(operator.textContent);
    moNode.appendChild(text);
    EnrichAttr.setAttributes(moNode, operator);
    moNode.setAttribute(EnrichAttr.Attribute.ADDED, 'true');
    return moNode;
}
export function setOperatorAttribute(semantic, content) {
    const operator = semantic.type + (semantic.textContent ? ',' + semantic.textContent : '');
    content.forEach(function (c) {
        getInnerNode(c).setAttribute(EnrichAttr.Attribute.OPERATOR, operator);
    });
}
export function getInnerNode(node) {
    const children = DomUtil.toArray(node.childNodes);
    if (!children) {
        return node;
    }
    const remainder = children.filter(function (child) {
        return !isIgnorable(child);
    });
    const result = [];
    for (let i = 0, remain; (remain = remainder[i]); i++) {
        if (SemanticUtil.hasEmptyTag(remain) &&
            remain.getAttribute(EnrichAttr.Attribute.TYPE) !==
                SemanticType.PUNCTUATION) {
            const nextInner = getInnerNode(remain);
            if (nextInner && nextInner !== remain) {
                result.push(nextInner);
            }
        }
        else {
            result.push(remain);
        }
    }
    if (result.length === 1) {
        return result[0];
    }
    return node;
}
function formattedOutput(element, name, wiki = false) {
    const output = EnrichAttr.removeAttributePrefix(DomUtil.formatXml(element.toString()));
    return wiki ? name + ':\n```html\n' + output + '\n```\n' : output;
}
export function collapsePunctuated(semantic, opt_children) {
    const optional = !!opt_children;
    const children = opt_children || [];
    const parent = semantic.parent;
    const contentIds = semantic.contentNodes.map(function (x) {
        return x.id;
    });
    contentIds.unshift('c');
    const childIds = [semantic.id, contentIds];
    for (let i = 0, child; (child = semantic.childNodes[i]); i++) {
        const mmlChild = walkTree(child);
        children.push(mmlChild);
        const innerNode = getInnerNode(mmlChild);
        if (parent && !optional) {
            innerNode.setAttribute(EnrichAttr.Attribute.PARENT, parent.id.toString());
        }
        childIds.push(child.id);
    }
    return childIds;
}
