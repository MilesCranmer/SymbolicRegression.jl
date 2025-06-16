"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.OutputError = exports.Precondition = exports.Action = exports.Component = exports.ActionType = exports.SpeechRule = void 0;
const engine_js_1 = require("../common/engine.js");
const Grammar = require("./grammar.js");
class SpeechRule {
    constructor(name, dynamicCstr, precondition, action) {
        this.name = name;
        this.dynamicCstr = dynamicCstr;
        this.precondition = precondition;
        this.action = action;
        this.context = null;
    }
    toString() {
        return (this.name +
            ' | ' +
            this.dynamicCstr.toString() +
            ' | ' +
            this.precondition.toString() +
            ' ==> ' +
            this.action.toString());
    }
}
exports.SpeechRule = SpeechRule;
var ActionType;
(function (ActionType) {
    ActionType["NODE"] = "NODE";
    ActionType["MULTI"] = "MULTI";
    ActionType["TEXT"] = "TEXT";
    ActionType["PERSONALITY"] = "PERSONALITY";
})(ActionType || (exports.ActionType = ActionType = {}));
function actionFromString(str) {
    switch (str) {
        case '[n]':
            return ActionType.NODE;
        case '[m]':
            return ActionType.MULTI;
        case '[t]':
            return ActionType.TEXT;
        case '[p]':
            return ActionType.PERSONALITY;
        default:
            throw 'Parse error: ' + str;
    }
}
function actionToString(speechType) {
    switch (speechType) {
        case ActionType.NODE:
            return '[n]';
        case ActionType.MULTI:
            return '[m]';
        case ActionType.TEXT:
            return '[t]';
        case ActionType.PERSONALITY:
            return '[p]';
        default:
            throw 'Unknown type error: ' + speechType;
    }
}
class Component {
    static grammarFromString(grammar) {
        return Grammar.Grammar.parseInput(grammar);
    }
    static fromString(input) {
        const output = {
            type: actionFromString(input.substring(0, 3))
        };
        let rest = input.slice(3).trim();
        if (!rest) {
            throw new OutputError('Missing content.');
        }
        switch (output.type) {
            case ActionType.TEXT:
                if (rest[0] === '"') {
                    const quotedString = splitString(rest, '\\(')[0].trim();
                    if (quotedString.slice(-1) !== '"') {
                        throw new OutputError('Invalid string syntax.');
                    }
                    output.content = quotedString;
                    rest = rest.slice(quotedString.length).trim();
                    if (rest.indexOf('(') === -1) {
                        rest = '';
                    }
                    break;
                }
            case ActionType.NODE:
            case ActionType.MULTI:
                {
                    const bracket = rest.indexOf(' (');
                    if (bracket === -1) {
                        output.content = rest.trim();
                        rest = '';
                        break;
                    }
                    output.content = rest.substring(0, bracket).trim();
                    rest = rest.slice(bracket).trim();
                }
                break;
        }
        if (rest) {
            const attributes = Component.attributesFromString(rest);
            if (attributes.grammar) {
                output.grammar = attributes.grammar;
                delete attributes.grammar;
            }
            if (Object.keys(attributes).length) {
                output.attributes = attributes;
            }
        }
        return new Component(output);
    }
    static attributesFromString(attrs) {
        if (attrs[0] !== '(' || attrs.slice(-1) !== ')') {
            throw new OutputError('Invalid attribute expression: ' + attrs);
        }
        const attributes = {};
        const attribs = splitString(attrs.slice(1, -1), ',');
        for (const attr of attribs) {
            const colon = attr.indexOf(':');
            if (colon === -1) {
                attributes[attr.trim()] = 'true';
            }
            else {
                const key = attr.substring(0, colon).trim();
                const value = attr.slice(colon + 1).trim();
                attributes[key] =
                    key === Grammar.ATTRIBUTE
                        ? Component.grammarFromString(value)
                        : value;
            }
        }
        return attributes;
    }
    constructor({ type, content, attributes, grammar }) {
        this.type = type;
        this.content = content;
        this.attributes = attributes;
        this.grammar = grammar;
    }
    toString() {
        let strs = '';
        strs += actionToString(this.type);
        strs += this.content ? ' ' + this.content : '';
        const attrs = this.attributesToString();
        strs += attrs ? ' ' + attrs : '';
        return strs;
    }
    grammarToString() {
        return this.getGrammar().join(':');
    }
    getGrammar() {
        if (!this.grammar) {
            return [];
        }
        const attribs = [];
        for (const [key, val] of Object.entries(this.grammar)) {
            attribs.push(val === true ? key : val === false ? `!${key}` : `${key}=${val}`);
        }
        return attribs;
    }
    attributesToString() {
        const attribs = this.getAttributes();
        const grammar = this.grammarToString();
        if (grammar) {
            attribs.push('grammar:' + grammar);
        }
        return attribs.length > 0 ? '(' + attribs.join(', ') + ')' : '';
    }
    getAttributes() {
        if (!this.attributes) {
            return [];
        }
        const attribs = [];
        for (const [key, val] of Object.entries(this.attributes)) {
            attribs.push(val === 'true' ? key : `${key}:${val}`);
        }
        return attribs;
    }
}
exports.Component = Component;
class Action {
    static fromString(input) {
        const comps = splitString(input, ';')
            .filter(function (x) {
            return x.match(/\S/);
        })
            .map(function (x) {
            return x.trim();
        });
        const newComps = [];
        for (let i = 0, m = comps.length; i < m; i++) {
            const comp = Component.fromString(comps[i]);
            if (comp) {
                newComps.push(comp);
            }
        }
        Action.naiveSpan(newComps);
        return new Action(newComps);
    }
    static naiveSpan(comps) {
        var _a;
        let first = false;
        for (let i = 0, comp; (comp = comps[i]); i++) {
            if (first &&
                (comp.type !== ActionType.TEXT ||
                    (comp.content[0] !== '"' && !comp.content.match(/^CSF/))))
                continue;
            if (!first && comp.type === ActionType.PERSONALITY)
                continue;
            if (!first) {
                first = true;
                continue;
            }
            if ((_a = comp.attributes) === null || _a === void 0 ? void 0 : _a.span)
                continue;
            const next = comps[i + 1];
            if (next && next.type !== ActionType.NODE)
                continue;
            Action.addNaiveSpan(comp, next ? next.content : 'LAST');
        }
    }
    static addNaiveSpan(comp, span) {
        if (!comp.attributes) {
            comp.attributes = {};
        }
        comp.attributes['span'] = span;
    }
    constructor(components) {
        this.components = components;
    }
    toString() {
        const comps = this.components.map(function (c) {
            return c.toString();
        });
        return comps.join('; ');
    }
}
exports.Action = Action;
class Precondition {
    static constraintValue(constr, priorities) {
        for (let i = 0, regexp; (regexp = priorities[i]); i++) {
            if (constr.match(regexp)) {
                return ++i;
            }
        }
        return 0;
    }
    toString() {
        const constrs = this.constraints.join(', ');
        return `${this.query}, ${constrs} (${this.priority}, ${this.rank})`;
    }
    constructor(query, ...cstr) {
        this.query = query;
        this.constraints = cstr;
        const [exists, user] = this.presetPriority();
        this.priority = exists ? user : this.calculatePriority();
    }
    calculatePriority() {
        const query = Precondition.constraintValue(this.query, Precondition.queryPriorities);
        if (!query) {
            return 0;
        }
        const match = this.query.match(/^self::.+\[(.+)\]/);
        let attr = 0;
        if ((match === null || match === void 0 ? void 0 : match.length) && match[1]) {
            const inner = match[1];
            attr = Precondition.constraintValue(inner, Precondition.attributePriorities);
        }
        return query * 100 + attr * 10;
    }
    presetPriority() {
        if (!this.constraints.length) {
            return [false, 0];
        }
        const last = this.constraints[this.constraints.length - 1].match(/^priority=(.*$)/);
        if (!last) {
            return [false, 0];
        }
        this.constraints.pop();
        const numb = parseFloat(last[1]);
        return [true, isNaN(numb) ? 0 : numb];
    }
}
exports.Precondition = Precondition;
Precondition.queryPriorities = [
    /^self::\*$/,
    /^self::[\w-]+$/,
    /^self::\*\[.+\]$/,
    /^self::[\w-]+\[.+\]$/
];
Precondition.attributePriorities = [
    /^@[\w-]+$/,
    /^@[\w-]+!=".+"$/,
    /^not\(contains\(@[\w-]+,\s*".+"\)\)$/,
    /^contains\(@[\w-]+,".+"\)$/,
    /^@[\w-]+=".+"$/
];
class OutputError extends engine_js_1.SREError {
    constructor(msg) {
        super(msg);
        this.name = 'RuleError';
    }
}
exports.OutputError = OutputError;
function splitString(str, sep) {
    const strList = [];
    let prefix = '';
    while (str !== '') {
        const sepPos = str.search(sep);
        if (sepPos === -1) {
            if ((str.match(/"/g) || []).length % 2 !== 0) {
                throw new OutputError('Invalid string in expression: ' + str);
            }
            strList.push(prefix + str);
            prefix = '';
            str = '';
        }
        else if ((str.substring(0, sepPos).match(/"/g) || []).length % 2 === 0) {
            strList.push(prefix + str.substring(0, sepPos));
            prefix = '';
            str = str.substring(sepPos + 1);
        }
        else {
            const nextQuot = str.substring(sepPos).search('"');
            if (nextQuot === -1) {
                throw new OutputError('Invalid string in expression: ' + str);
            }
            else {
                prefix = prefix + str.substring(0, sepPos + nextQuot + 1);
                str = str.substring(sepPos + nextQuot + 1);
            }
        }
    }
    if (prefix) {
        strList.push(prefix);
    }
    return strList;
}
