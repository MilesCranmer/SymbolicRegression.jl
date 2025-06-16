"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SemanticMeaningCollator = exports.SemanticNodeCollator = exports.SemanticDefault = void 0;
const SemanticAttr = require("./semantic_attr.js");
const semantic_ordering_js_1 = require("./semantic_ordering.js");
function key(symbol, font) {
    return symbol.match(/^.+:.+$/) || !font ? symbol : symbol + ':' + font;
}
class SemanticDefault extends Map {
    set(symbol, meaning) {
        super.set(key(symbol, meaning.font), meaning);
        return this;
    }
    setNode(node) {
        this.set(node.textContent, node.meaning());
    }
    get(symbol, font = null) {
        return super.get(key(symbol, font));
    }
    getNode(node) {
        return this.get(node.textContent, node.font);
    }
}
exports.SemanticDefault = SemanticDefault;
class SemanticCollator extends Map {
    add(symbol, entry) {
        const list = this.get(symbol);
        if (list) {
            list.push(entry);
        }
        else {
            super.set(symbol, [entry]);
        }
    }
    get(symbol, font = null) {
        return super.get(key(symbol, font));
    }
    getNode(node) {
        return this.get(node.textContent, node.font);
    }
    minimize() {
        for (const [key, entry] of this) {
            if (entry.length === 1) {
                this.delete(key);
            }
        }
    }
    isMultiValued() {
        for (const value of this.values()) {
            if (value.length > 1) {
                return true;
            }
        }
        return false;
    }
}
class SemanticNodeCollator extends SemanticCollator {
    add(symbol, entry) {
        super.add(key(symbol, entry.font), entry);
    }
    addNode(node) {
        this.add(node.textContent, node);
    }
    toString() {
        const outer = [];
        for (const [key, nodes] of this) {
            const length = Array(key.length + 3).join(' ');
            const inner = nodes.map((node) => node.toString()).join('\n' + length);
            outer.push(key + ': ' + inner);
        }
        return outer.join('\n');
    }
    collateMeaning() {
        const collator = new SemanticMeaningCollator();
        for (const [key, val] of this) {
            collator.set(key, val.map((node) => node.meaning()));
        }
        return collator;
    }
}
exports.SemanticNodeCollator = SemanticNodeCollator;
class SemanticMeaningCollator extends SemanticCollator {
    add(symbol, entry) {
        const list = this.get(symbol, entry.font);
        if (!list ||
            !list.find(function (x) {
                return SemanticAttr.equal(x, entry);
            })) {
            super.add(key(symbol, entry.font), entry);
        }
    }
    addNode(node) {
        this.add(node.textContent, node.meaning());
    }
    toString() {
        const outer = [];
        for (const [key, nodes] of this) {
            const length = Array(key.length + 3).join(' ');
            const inner = nodes
                .map((node) => `{type: ${node.type}, role: ${node.role}, font: ${node.font}}`)
                .join('\n' + length);
            outer.push(key + ': ' + inner);
        }
        return outer.join('\n');
    }
    reduce() {
        for (const [key, val] of this) {
            if (val.length !== 1) {
                this.set(key, (0, semantic_ordering_js_1.reduce)(val));
            }
        }
    }
    default() {
        const def = new SemanticDefault();
        for (const [key, val] of this) {
            if (val.length === 1) {
                def.set(key, val[0]);
            }
        }
        return def;
    }
    newDefault() {
        const oldDefault = this.default();
        this.reduce();
        const newDefault = this.default();
        return oldDefault.size !== newDefault.size ? newDefault : null;
    }
}
exports.SemanticMeaningCollator = SemanticMeaningCollator;
