import { KeyCode } from './event_util.js';
export class Processor {
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
Processor.LocalState = { walker: null, speechGenerator: null, highlighter: null };
export class KeyProcessor extends Processor {
    static getKey_(key) {
        return typeof key === 'string'
            ?
                KeyCode[key.toUpperCase()]
            : key;
    }
    constructor(name, methods) {
        super(name, methods);
        this.key = methods.key || KeyProcessor.getKey_;
    }
}
