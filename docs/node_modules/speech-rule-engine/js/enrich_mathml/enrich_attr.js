"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EnrichAttributes = exports.Attribute = void 0;
exports.makeIdList = makeIdList;
exports.setAttributes = setAttributes;
exports.removeAttributePrefix = removeAttributePrefix;
exports.addPrefix = addPrefix;
exports.addMrow = addMrow;
const DomUtil = require("../common/dom_util.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const Prefix = 'data-semantic-';
var Attribute;
(function (Attribute) {
    Attribute["ADDED"] = "data-semantic-added";
    Attribute["ALTERNATIVE"] = "data-semantic-alternative";
    Attribute["CHILDREN"] = "data-semantic-children";
    Attribute["COLLAPSED"] = "data-semantic-collapsed";
    Attribute["CONTENT"] = "data-semantic-content";
    Attribute["EMBELLISHED"] = "data-semantic-embellished";
    Attribute["FENCEPOINTER"] = "data-semantic-fencepointer";
    Attribute["FONT"] = "data-semantic-font";
    Attribute["ID"] = "data-semantic-id";
    Attribute["ANNOTATION"] = "data-semantic-annotation";
    Attribute["ATTRIBUTES"] = "data-semantic-attributes";
    Attribute["OPERATOR"] = "data-semantic-operator";
    Attribute["OWNS"] = "data-semantic-owns";
    Attribute["PARENT"] = "data-semantic-parent";
    Attribute["POSTFIX"] = "data-semantic-postfix";
    Attribute["PREFIX"] = "data-semantic-prefix";
    Attribute["ROLE"] = "data-semantic-role";
    Attribute["SPEECH"] = "data-semantic-speech";
    Attribute["STRUCTURE"] = "data-semantic-structure";
    Attribute["SUMMARY"] = "data-semantic-summary";
    Attribute["TYPE"] = "data-semantic-type";
})(Attribute || (exports.Attribute = Attribute = {}));
exports.EnrichAttributes = [
    Attribute.ADDED,
    Attribute.ALTERNATIVE,
    Attribute.CHILDREN,
    Attribute.COLLAPSED,
    Attribute.CONTENT,
    Attribute.EMBELLISHED,
    Attribute.FENCEPOINTER,
    Attribute.FONT,
    Attribute.ID,
    Attribute.ANNOTATION,
    Attribute.ATTRIBUTES,
    Attribute.OPERATOR,
    Attribute.OWNS,
    Attribute.PARENT,
    Attribute.POSTFIX,
    Attribute.PREFIX,
    Attribute.ROLE,
    Attribute.SPEECH,
    Attribute.STRUCTURE,
    Attribute.SUMMARY,
    Attribute.TYPE
];
function makeIdList(nodes) {
    return nodes
        .map(function (node) {
        return node.id;
    })
        .join(',');
}
function setAttributes(mml, semantic) {
    mml.setAttribute(Attribute.TYPE, semantic.type);
    const attributes = semantic.allAttributes();
    for (let i = 0, attr; (attr = attributes[i]); i++) {
        mml.setAttribute(Prefix + attr[0].toLowerCase(), attr[1]);
    }
    if (semantic.childNodes.length) {
        mml.setAttribute(Attribute.CHILDREN, makeIdList(semantic.childNodes));
    }
    if (semantic.contentNodes.length) {
        mml.setAttribute(Attribute.CONTENT, makeIdList(semantic.contentNodes));
    }
    if (semantic.parent) {
        mml.setAttribute(Attribute.PARENT, semantic.parent.id.toString());
    }
    const external = semantic.attributesXml();
    if (external) {
        mml.setAttribute(Attribute.ATTRIBUTES, external);
    }
    setPostfix(mml, semantic);
}
function setPostfix(mml, semantic) {
    const postfix = [];
    if (semantic.role === semantic_meaning_js_1.SemanticRole.MGLYPH) {
        postfix.push('image');
    }
    if (semantic.attributes['href']) {
        postfix.push('link');
    }
    if (postfix.length) {
        mml.setAttribute(Attribute.POSTFIX, postfix.join(' '));
    }
}
function removeAttributePrefix(mml) {
    return mml.toString().replace(new RegExp(Prefix, 'g'), '');
}
function addPrefix(attr) {
    return (Prefix + attr);
}
function addMrow() {
    const mrow = DomUtil.createElement('mrow');
    mrow.setAttribute(Attribute.ADDED, 'true');
    return mrow;
}
