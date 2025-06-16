"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SyntaxWalker = void 0;
const base_util_js_1 = require("../common/base_util.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
const abstract_walker_js_1 = require("./abstract_walker.js");
const levels_js_1 = require("./levels.js");
class SyntaxWalker extends abstract_walker_js_1.AbstractWalker {
    constructor(node, generator, highlighter, xml) {
        super(node, generator, highlighter, xml);
        this.node = node;
        this.generator = generator;
        this.highlighter = highlighter;
        this.levels = null;
        this.restoreState();
    }
    initLevels() {
        const levels = new levels_js_1.Levels();
        levels.push([this.primaryId()]);
        return levels;
    }
    up() {
        super.up();
        const parent = this.previousLevel();
        if (!parent) {
            return null;
        }
        this.levels.pop();
        return this.singletonFocus(parent);
    }
    down() {
        super.down();
        const children = this.nextLevel();
        if (children.length === 0) {
            return null;
        }
        const focus = this.singletonFocus(children[0]);
        if (focus) {
            this.levels.push(children);
        }
        return focus;
    }
    combineContentChildren(type, role, content, children) {
        switch (type) {
            case semantic_meaning_js_1.SemanticType.RELSEQ:
            case semantic_meaning_js_1.SemanticType.INFIXOP:
            case semantic_meaning_js_1.SemanticType.MULTIREL:
                return (0, base_util_js_1.interleaveLists)(children, content);
            case semantic_meaning_js_1.SemanticType.PREFIXOP:
                return content.concat(children);
            case semantic_meaning_js_1.SemanticType.POSTFIXOP:
                return children.concat(content);
            case semantic_meaning_js_1.SemanticType.MATRIX:
            case semantic_meaning_js_1.SemanticType.VECTOR:
            case semantic_meaning_js_1.SemanticType.FENCED:
                children.unshift(content[0]);
                children.push(content[1]);
                return children;
            case semantic_meaning_js_1.SemanticType.CASES:
                children.unshift(content[0]);
                return children;
            case semantic_meaning_js_1.SemanticType.PUNCTUATED:
                if (role === semantic_meaning_js_1.SemanticRole.TEXT) {
                    return (0, base_util_js_1.interleaveLists)(children, content);
                }
                return children;
            case semantic_meaning_js_1.SemanticType.APPL:
                return [children[0], content[0], children[1]];
            case semantic_meaning_js_1.SemanticType.ROOT:
                return [children[0], children[1]];
            default:
                return children;
        }
    }
    left() {
        super.left();
        const index = this.levels.indexOf(this.primaryId());
        if (index === null) {
            return null;
        }
        const id = this.levels.get(index - 1);
        return id ? this.singletonFocus(id) : null;
    }
    right() {
        super.right();
        const index = this.levels.indexOf(this.primaryId());
        if (index === null) {
            return null;
        }
        const id = this.levels.get(index + 1);
        return id ? this.singletonFocus(id) : null;
    }
    findFocusOnLevel(id) {
        return this.singletonFocus(id.toString());
    }
    focusDomNodes() {
        return [this.getFocus().getDomPrimary()];
    }
    focusSemanticNodes() {
        return [this.getFocus().getSemanticPrimary()];
    }
}
exports.SyntaxWalker = SyntaxWalker;
