"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.EuroStore = exports.BrailleStore = void 0;
const math_store_js_1 = require("./math_store.js");
const semantic_annotations_js_1 = require("../semantic_tree/semantic_annotations.js");
const semantic_attr_js_1 = require("../semantic_tree/semantic_attr.js");
const semantic_meaning_js_1 = require("../semantic_tree/semantic_meaning.js");
class BrailleStore extends math_store_js_1.MathStore {
    constructor() {
        super(...arguments);
        this.modality = 'braille';
        this.customTranscriptions = {
            '\u22ca': '⠈⠡⠳'
        };
    }
    evaluateString(str) {
        const descs = [];
        const text = Array.from(str);
        for (let i = 0; i < text.length; i++) {
            descs.push(this.evaluateCharacter(text[i]));
        }
        return descs;
    }
    annotations() {
        for (let i = 0, annotator; (annotator = this.annotators[i]); i++) {
            (0, semantic_annotations_js_1.activate)(this.locale, annotator);
        }
    }
}
exports.BrailleStore = BrailleStore;
class EuroStore extends BrailleStore {
    constructor() {
        super(...arguments);
        this.locale = 'euro';
        this.customTranscriptions = {};
        this.customCommands = {
            '\\cdot': '*',
            '\\lt': '<',
            '\\gt': '>'
        };
        this.lastSpecial = false;
        this.specialChars = ['^', '_', '{', '}'];
    }
    evaluateString(str) {
        const regexp = /(\\[a-z]+|\\{|\\}|\\\\)/i;
        const split = str.split(regexp);
        const cleaned = this.cleanup(split);
        return super.evaluateString(cleaned);
    }
    cleanup(commands) {
        const cleaned = [];
        let intext = false;
        let lastcom = null;
        for (let command of commands) {
            if (command.match(/^\\/)) {
                if (command === '\\text') {
                    intext = true;
                }
                if (this.addSpace(semantic_attr_js_1.SemanticMap.LatexCommands.get(command))) {
                    cleaned.push(' ');
                }
                command = this.customCommands[command] || command;
                const newcom = command.match(/^\\/);
                if (newcom && command.match(/^\\[a-zA-Z]+$/) && lastcom) {
                    cleaned.push(' ');
                }
                lastcom = newcom ? command : null;
                cleaned.push(command);
                continue;
            }
            const rest = command.split('');
            for (const char of rest) {
                if (intext) {
                    cleaned.push(char);
                    intext = char !== '}';
                    lastcom = null;
                    continue;
                }
                if (char.match(/[a-z]/i) && lastcom) {
                    lastcom = null;
                    cleaned.push(' ');
                    cleaned.push(char);
                    continue;
                }
                if (char.match(/\s/))
                    continue;
                if (this.addSpace(char)) {
                    cleaned.push(' ');
                }
                cleaned.push(char);
                lastcom = null;
            }
        }
        return cleaned.join('');
    }
    addSpace(char) {
        if (!char)
            return false;
        if (this.specialChars.indexOf(char) !== -1) {
            this.lastSpecial = true;
            return false;
        }
        if (this.lastSpecial) {
            this.lastSpecial = false;
            return false;
        }
        const meaning = semantic_attr_js_1.SemanticMap.Meaning.get(char);
        return (meaning.type === semantic_meaning_js_1.SemanticType.OPERATOR ||
            meaning.type === semantic_meaning_js_1.SemanticType.RELATION ||
            (meaning.type === semantic_meaning_js_1.SemanticType.PUNCTUATION &&
                meaning.role === semantic_meaning_js_1.SemanticRole.COLON));
    }
}
exports.EuroStore = EuroStore;
