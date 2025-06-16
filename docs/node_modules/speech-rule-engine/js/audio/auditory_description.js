"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuditoryDescription = exports.AuditoryList = exports.AuditoryItem = void 0;
const grammar_js_1 = require("../rule_engine/grammar.js");
const span_js_1 = require("./span.js");
class AuditoryItem {
    constructor(data = null) {
        this.data = data;
        this.prev = null;
        this.next = null;
    }
}
exports.AuditoryItem = AuditoryItem;
class AuditoryList extends Set {
    constructor(descrs) {
        super();
        this.annotations = [];
        this.anchor = new AuditoryItem();
        this.anchor.next = this.anchor;
        this.anchor.prev = this.anchor;
        descrs.forEach((d) => {
            const item = new AuditoryItem(d);
            if (d.annotation) {
                this.annotations.push(item);
            }
            this.push(item);
        });
    }
    first() {
        return this.empty ? null : this.anchor.next;
    }
    last() {
        return this.empty ? null : this.anchor.prev;
    }
    push(item) {
        item.next = this.anchor;
        item.prev = this.anchor.prev;
        item.prev.next = item;
        this.anchor.prev = item;
        super.add(item);
    }
    pop() {
        const item = this.last();
        if (!item) {
            return null;
        }
        this.delete(item);
        return item;
    }
    delete(item) {
        if (!this.has(item)) {
            return false;
        }
        super.delete(item);
        item.prev.next = item.next;
        item.next = item.prev;
        return true;
    }
    insertAfter(descr, item) {
        this.insertBefore(descr, item.next);
    }
    insertBefore(descr, item) {
        const nitem = new AuditoryItem(descr);
        if (!item || !this.has(item)) {
            this.push(nitem);
            return;
        }
        item.prev.next = nitem;
        nitem.prev = item.prev;
        nitem.next = item;
        item.prev = nitem;
    }
    prevText(item) {
        do {
            item = item.prev;
        } while (item !== this.anchor && !item.data.text);
        return item === this.anchor ? null : item;
    }
    *[Symbol.iterator]() {
        let current = this.anchor.next;
        while (current !== this.anchor) {
            yield current;
            current = current.next;
        }
    }
    nextText(item) {
        while (item !== this.anchor && !item.data.text) {
            item = item.next;
        }
        return item;
    }
    clear() {
        this.anchor.next = this.anchor;
        this.anchor.prev = this.anchor;
        super.clear();
    }
    empty() {
        return this.anchor.prev === this.anchor && this.anchor === this.anchor.next;
    }
    toList() {
        const result = [];
        let item = this.anchor.next;
        while (item !== this.anchor) {
            result.push(item.data);
            item = item.next;
        }
        return result;
    }
}
exports.AuditoryList = AuditoryList;
class AuditoryDescription {
    static create(args, flags = {}) {
        args.text = grammar_js_1.Grammar.getInstance().apply(args.text, flags);
        return new AuditoryDescription(args);
    }
    constructor({ context, text, userValue, annotation, attributes, personality, layout }) {
        this.context = context || '';
        this.text = text || '';
        this.userValue = userValue || '';
        this.annotation = annotation || '';
        this.attributes = attributes || {};
        this.personality = personality || {};
        this.layout = layout || '';
    }
    isEmpty() {
        return (this.context.length === 0 &&
            this.text.length === 0 &&
            this.userValue.length === 0 &&
            this.annotation.length === 0);
    }
    clone() {
        let personality;
        if (this.personality) {
            personality = {};
            for (const [key, val] of Object.entries(this.personality)) {
                personality[key] = val;
            }
        }
        let attributes;
        if (this.attributes) {
            attributes = {};
            for (const [key, val] of Object.entries(this.attributes)) {
                attributes[key] = val;
            }
        }
        return new AuditoryDescription({
            context: this.context,
            text: this.text,
            userValue: this.userValue,
            annotation: this.annotation,
            personality: personality,
            attributes: attributes,
            layout: this.layout
        });
    }
    toString() {
        return ('AuditoryDescription(context="' +
            this.context +
            '" ' +
            ' text="' +
            this.text +
            '" ' +
            ' userValue="' +
            this.userValue +
            '" ' +
            ' annotation="' +
            this.annotation +
            '")');
    }
    descriptionString() {
        return this.context && this.text
            ? this.context + ' ' + this.text
            : this.context || this.text;
    }
    descriptionSpan() {
        return span_js_1.Span.stringAttr(this.descriptionString(), this.attributes);
    }
    equals(that) {
        return (this.context === that.context &&
            this.text === that.text &&
            this.userValue === that.userValue &&
            this.annotation === that.annotation);
    }
}
exports.AuditoryDescription = AuditoryDescription;
