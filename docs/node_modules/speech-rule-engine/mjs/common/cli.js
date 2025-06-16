var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { Axis, DynamicCstr } from '../rule_engine/dynamic_cstr.js';
import * as MathCompoundStore from '../rule_engine/math_compound_store.js';
import { SpeechRuleEngine } from '../rule_engine/speech_rule_engine.js';
import { ClearspeakPreferences } from '../speech_rules/clearspeak_preferences.js';
import { Debugger } from './debugger.js';
import { EnginePromise, SREError } from './engine.js';
import * as EngineConst from './engine_const.js';
import * as ProcessorFactory from './processor_factory.js';
import * as System from './system.js';
import { SystemExternal } from './system_external.js';
import { Variables } from './variables.js';
export class Cli {
    constructor() {
        this.setup = {
            mode: EngineConst.Mode.SYNC
        };
        this.processors = [];
        this.output = Cli.process.stdout;
        this.dp = new SystemExternal.xmldom.DOMParser({
            onError: (_key, _msg) => {
                throw new SREError('XML DOM error!');
            }
        });
    }
    set(arg, value, _def) {
        this.setup[arg] = typeof value === 'undefined' ? true : value;
    }
    processor(processor) {
        this.processors.push(processor);
    }
    loadLocales() {
        return __awaiter(this, void 0, void 0, function* () {
            for (const loc of Variables.LOCALES.keys()) {
                yield System.setupEngine({ locale: loc });
            }
        });
    }
    enumerate() {
        return __awaiter(this, arguments, void 0, function* (all = false) {
            const promise = System.setupEngine(this.setup);
            const order = DynamicCstr.DEFAULT_ORDER.slice(0, -1);
            return (all ? this.loadLocales() : promise).then(() => EnginePromise.getall().then(() => {
                const length = order.map((x) => x.length);
                const maxLength = (obj, index) => {
                    length[index] = Math.max.apply(null, Object.keys(obj)
                        .map((x) => x.length)
                        .concat(length[index]));
                };
                const compStr = (str, length) => str + new Array(length - str.length + 1).join(' ');
                let dynamic = SpeechRuleEngine.getInstance().enumerate();
                dynamic = MathCompoundStore.enumerate(dynamic);
                const table = [];
                maxLength(dynamic, 0);
                for (const [ax1, dyna1] of Object.entries(dynamic)) {
                    let clear1 = true;
                    maxLength(dyna1, 1);
                    for (const [ax2, dyna2] of Object.entries(dyna1)) {
                        let clear2 = true;
                        maxLength(dyna2, 2);
                        for (const [ax3, dyna3] of Object.entries(dyna2)) {
                            const styles = Object.keys(dyna3).sort();
                            if (ax3 === 'clearspeak') {
                                let clear3 = true;
                                const prefs = ClearspeakPreferences.getLocalePreferences(dynamic)[ax1];
                                if (!prefs) {
                                    continue;
                                }
                                for (const dyna4 of Object.values(prefs)) {
                                    table.push([
                                        compStr(clear1 ? ax1 : '', length[0]),
                                        compStr(clear2 ? ax2 : '', length[1]),
                                        compStr(clear3 ? ax3 : '', length[2]),
                                        dyna4.join(', ')
                                    ]);
                                    clear1 = false;
                                    clear2 = false;
                                    clear3 = false;
                                }
                            }
                            else {
                                table.push([
                                    compStr(clear1 ? ax1 : '', length[0]),
                                    compStr(clear2 ? ax2 : '', length[1]),
                                    compStr(ax3, length[2]),
                                    styles.join(', ')
                                ]);
                            }
                            clear1 = false;
                            clear2 = false;
                        }
                    }
                }
                let i = 0;
                const header = order.map((x) => compStr(x, length[i++]));
                const markdown = Cli.commander.opts().pprint;
                const separator = length.map((x) => new Array(x + 1).join(markdown ? '-' : '='));
                if (!markdown) {
                    separator[i - 1] = separator[i - 1] + '========================';
                }
                table.unshift(separator);
                table.unshift(header);
                let output = table.map((x) => x.join(' | '));
                if (markdown) {
                    output = output.map((x) => `| ${x} |`);
                    output.unshift(`# Options SRE v${System.version}\n`);
                }
                console.info(output.join('\n'));
            }));
        });
    }
    execute(input) {
        EnginePromise.getall().then(() => {
            this.runProcessors_((proc, file) => this.output.write(System.processFile(proc, file) + '\n'), input);
        });
    }
    readline() {
        Cli.process.stdin.setEncoding('utf8');
        const inter = SystemExternal.extRequire('readline').createInterface({
            input: Cli.process.stdin,
            output: this.output
        });
        let input = '';
        inter.on('line', ((expr) => {
            input += expr;
            if (this.readExpression_(input)) {
                inter.close();
            }
        }).bind(this));
        inter.on('close', (() => {
            this.runProcessors_((proc, expr) => {
                inter.output.write(ProcessorFactory.output(proc, expr) + '\n');
            }, input);
            System.engineReady().then(() => Debugger.getInstance().exit(() => System.exit(0)));
        }).bind(this));
    }
    commandLine() {
        return __awaiter(this, void 0, void 0, function* () {
            const commander = Cli.commander;
            const system = System;
            const set = ((key) => {
                return (val, def) => this.set(key, val, def);
            }).bind(this);
            const processor = this.processor.bind(this);
            commander
                .version(system.version)
                .usage('[options] <file ...>')
                .option('-i, --input [name]', 'Input file [name]. (Deprecated)')
                .option('-o, --output [name]', 'Output file [name]. Defaults to stdout.')
                .option('-d, --domain [name]', 'Speech rule set [name]. See --options' + ' for details.', set(Axis.DOMAIN), DynamicCstr.DEFAULT_VALUES[Axis.DOMAIN])
                .option('-s, --style [name]', 'Speech style [name]. See --options' + ' for details.', set(Axis.STYLE), DynamicCstr.DEFAULT_VALUES[Axis.STYLE])
                .option('-c, --locale [code]', 'Locale [code].', set(Axis.LOCALE), DynamicCstr.DEFAULT_VALUES[Axis.LOCALE])
                .option('-b, --modality [name]', 'Modality [name].', set(Axis.MODALITY), DynamicCstr.DEFAULT_VALUES[Axis.MODALITY])
                .option('-k, --markup [name]', 'Generate speech output with markup tags.', set('markup'), 'none')
                .option('-e, --automark', 'Automatically set marks for external reference.', set('automark'))
                .option('-L, --linebreaks', 'Linebreak marking in 2D output.', set('linebreaks'))
                .option('-r, --rate [value]', 'Base rate [value] for tagged speech' + ' output.', set('rate'), '100')
                .option('-p, --speech', 'Generate speech output (default).', () => processor('speech'))
                .option('-a, --audit', 'Generate auditory descriptions (JSON format).', () => processor('description'))
                .option('-j, --json', 'Generate JSON of semantic tree.', () => processor('json'))
                .option('-x, --xml', 'Generate XML of semantic tree.', () => processor('semantic'))
                .option('-m, --mathml', 'Generate enriched MathML.', () => processor('enriched'))
                .option('-u, --rebuild', 'Rebuild semantic tree from enriched MathML.', () => processor('rebuild'))
                .option('-t, --latex', 'Accepts LaTeX input for certain locale/modality combinations.', () => processor('latex'))
                .option('-g, --generate <depth>', 'Include generated speech in enriched' +
                ' MathML (with -m option only).', set('speech'), 'none')
                .option('-w, --structure', 'Include structure attribute in enriched' +
                ' MathML (with -m option only).', set('structure'))
                .option('-A, --aria', 'Include aria tree annotations' +
                ' MathML (with -m and -w option only).', set('aria'))
                .option('-P, --pprint', 'Pretty print output whenever possible.', set('pprint'))
                .option('-f, --rules [name]', 'Loads a local rule file [name].', set('rules'))
                .option('-C, --subiso [name]', 'Supplementary country code (or similar) for the given locale.', set('subiso'))
                .option('-N, --number', 'Translate number to word.', () => processor('number'))
                .option('-O, --ordinal', 'Translate number to ordinal.', () => processor('ordinal'), 'ordinal')
                .option('-S, --numeric', 'Translate number to numeric ordinal.', () => processor('numericOrdinal'))
                .option('-F, --vulgar', 'Translate vulgar fraction to word. Provide vulgar fraction as slash seperated numbers.', () => processor('vulgar'))
                .option('-v, --verbose', 'Verbose mode.')
                .option('-l, --log [name]', 'Log file [name].')
                .option('--opt', 'List engine setup options. Output as markdown with -P option.')
                .option('--opt-all', 'List engine setup options for all available locales. Output as markdown with -P option.')
                .on('option:opt', () => {
                this.enumerate().then(() => System.exit(0));
            })
                .on('option:opt-all', () => {
                this.enumerate(true).then(() => System.exit(0));
            })
                .parse(Cli.process.argv);
            yield System.engineReady().then(() => System.setupEngine(this.setup));
            const options = Cli.commander.opts();
            if (options.output) {
                this.output = SystemExternal.fs.createWriteStream(options.output);
            }
            if (options.verbose) {
                yield Debugger.getInstance().init(options.log);
            }
            if (options.input) {
                this.execute(options.input);
            }
            if (Cli.commander.args.length) {
                Cli.commander.args.forEach(this.execute.bind(this));
                System.engineReady().then(() => Debugger.getInstance().exit(() => System.exit(0)));
            }
            else {
                this.readline();
            }
        });
    }
    runProcessors_(processor, input) {
        try {
            if (!this.processors.length) {
                this.processors.push('speech');
            }
            if (input) {
                this.processors.forEach((proc) => processor(proc, input));
            }
        }
        catch (err) {
            console.error(err.name + ': ' + err.message);
            Debugger.getInstance().exit(() => Cli.process.exit(1));
        }
    }
    readExpression_(input) {
        try {
            const testInput = input.replace(/(&|#|;)/g, '');
            this.dp.parseFromString(testInput, 'text/xml');
        }
        catch (_err) {
            return false;
        }
        return true;
    }
}
Cli.process = SystemExternal.extRequire('process');
Cli.commander = SystemExternal.documentSupported
    ? null
    : SystemExternal.extRequire('commander').program;
