"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.Span = void 0;
class Span {
    constructor(speech, attributes) {
        this.speech = speech;
        this.attributes = attributes;
    }
    static empty() {
        return new Span('', {});
    }
    static stringEmpty(str) {
        return new Span(str, {});
    }
    static stringAttr(str, attr) {
        return new Span(str, attr);
    }
    static singleton(str, def = {}) {
        return [Span.stringAttr(str, def)];
    }
    static node(str, node, def = {}) {
        const attr = Span.getAttributes(node);
        Object.assign(attr, def);
        return new Span(str, attr);
    }
    static getAttributes(node) {
        const attrs = {};
        for (const attr of Span.attributeList) {
            if (node.hasAttribute(attr)) {
                attrs[attr] = node.getAttribute(attr);
            }
        }
        return attrs;
    }
}
exports.Span = Span;
Span.attributeList = ['id', 'extid'];
