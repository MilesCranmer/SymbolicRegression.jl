"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.splitAttribute = splitAttribute;
exports.getAttribute = getAttribute;
exports.getSemanticRoot = getSemanticRoot;
exports.getBySemanticId = getBySemanticId;
exports.getAllBySemanticId = getAllBySemanticId;
const DomUtil = require("../common/dom_util.js");
const enrich_attr_js_1 = require("../enrich_mathml/enrich_attr.js");
function splitAttribute(attr) {
    return !attr ? [] : attr.split(/,/);
}
function getAttribute(node, attr) {
    return node.getAttribute(attr);
}
function getSemanticRoot(node) {
    if (node.hasAttribute(enrich_attr_js_1.Attribute.TYPE) &&
        !node.hasAttribute(enrich_attr_js_1.Attribute.PARENT)) {
        return node;
    }
    const semanticNodes = DomUtil.querySelectorAllByAttr(node, enrich_attr_js_1.Attribute.TYPE);
    for (let i = 0, semanticNode; (semanticNode = semanticNodes[i]); i++) {
        if (!semanticNode.hasAttribute(enrich_attr_js_1.Attribute.PARENT)) {
            return semanticNode;
        }
    }
    return node;
}
function getBySemanticId(root, id) {
    if (root.getAttribute(enrich_attr_js_1.Attribute.ID) === id) {
        return root;
    }
    return DomUtil.querySelectorAllByAttrValue(root, enrich_attr_js_1.Attribute.ID, id)[0];
}
function getAllBySemanticId(root, id) {
    if (root.getAttribute(enrich_attr_js_1.Attribute.ID) === id) {
        return [root];
    }
    return DomUtil.querySelectorAllByAttrValue(root, enrich_attr_js_1.Attribute.ID, id);
}
