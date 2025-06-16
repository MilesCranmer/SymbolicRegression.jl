import * as DomUtil from '../common/dom_util.js';
import { Attribute } from '../enrich_mathml/enrich_attr.js';
export function splitAttribute(attr) {
    return !attr ? [] : attr.split(/,/);
}
export function getAttribute(node, attr) {
    return node.getAttribute(attr);
}
export function getSemanticRoot(node) {
    if (node.hasAttribute(Attribute.TYPE) &&
        !node.hasAttribute(Attribute.PARENT)) {
        return node;
    }
    const semanticNodes = DomUtil.querySelectorAllByAttr(node, Attribute.TYPE);
    for (let i = 0, semanticNode; (semanticNode = semanticNodes[i]); i++) {
        if (!semanticNode.hasAttribute(Attribute.PARENT)) {
            return semanticNode;
        }
    }
    return node;
}
export function getBySemanticId(root, id) {
    if (root.getAttribute(Attribute.ID) === id) {
        return root;
    }
    return DomUtil.querySelectorAllByAttrValue(root, Attribute.ID, id)[0];
}
export function getAllBySemanticId(root, id) {
    if (root.getAttribute(Attribute.ID) === id) {
        return [root];
    }
    return DomUtil.querySelectorAllByAttrValue(root, Attribute.ID, id);
}
