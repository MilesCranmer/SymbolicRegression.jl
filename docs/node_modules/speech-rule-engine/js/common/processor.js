"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.KeyProcessor = exports.Processor = void 0;
const event_util_js_1 = require("./event_util.js");
class Processor {
    static stringify_(x) {
        return x ? x.toString() : x;
    }
    constructor(name, methods) {
        this.name = name;
        this.process = methods.processor;
        this.postprocess =
            methods.postprocessor || ((x, _y) => x);
        this.processor = this.postprocess
            ? function (x) {
                return this.postprocess(this.process(x), x);
            }
            : this.process;
        this.print = methods.print || Processor.stringify_;
        this.pprint = methods.pprint || this.print;
    }
}
exports.Processor = Processor;
Processor.LocalState = { walker: null, speechGenerator: null, highlighter: null };
class KeyProcessor extends Processor {
    static getKey_(key) {
        return typeof key === 'string'
            ?
                event_util_js_1.KeyCode[key.toUpperCase()]
            : key;
    }
    constructor(name, methods) {
        super(name, methods);
        this.key = methods.key || KeyProcessor.getKey_;
    }
}
exports.KeyProcessor = KeyProcessor;
