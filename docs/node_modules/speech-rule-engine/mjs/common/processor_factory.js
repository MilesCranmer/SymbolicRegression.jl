import * as AuralRendering from '../audio/aural_rendering.js';
import * as Enrich from '../enrich_mathml/enrich.js';
import * as HighlighterFactory from '../highlighter/highlighter_factory.js';
import { LOCALE } from '../l10n/locale.js';
import * as Semantic from '../semantic_tree/semantic.js';
import * as SpeechGeneratorFactory from '../speech_generator/speech_generator_factory.js';
import * as SpeechGeneratorUtil from '../speech_generator/speech_generator_util.js';
import * as WalkerFactory from '../walker/walker_factory.js';
import * as WalkerUtil from '../walker/walker_util.js';
import { RebuildStree } from '../walker/rebuild_stree.js';
import * as DomUtil from './dom_util.js';
import { Engine, SREError } from './engine.js';
import * as EngineConst from '../common/engine_const.js';
import { Processor, KeyProcessor } from './processor.js';
import * as XpathUtil from './xpath_util.js';
const PROCESSORS = new Map();
function set(processor) {
    PROCESSORS.set(processor.name, processor);
}
function get(name) {
    const processor = PROCESSORS.get(name);
    if (!processor) {
        throw new SREError('Unknown processor ' + name);
    }
    return processor;
}
export function process(name, expr) {
    const processor = get(name);
    try {
        return processor.processor(expr);
    }
    catch (_e) {
        throw new SREError('Processing error for expression ' + expr);
    }
}
function print(name, data) {
    const processor = get(name);
    return Engine.getInstance().pprint
        ? processor.pprint(data)
        : processor.print(data);
}
export function output(name, expr) {
    const processor = get(name);
    try {
        const data = processor.processor(expr);
        return Engine.getInstance().pprint
            ? processor.pprint(data)
            : processor.print(data);
    }
    catch (_e) {
        console.log(_e);
        throw new SREError('Processing error for expression ' + expr);
    }
}
export function keypress(name, expr) {
    const processor = get(name);
    const key = processor instanceof KeyProcessor ? processor.key(expr) : expr;
    const data = processor.processor(key);
    return Engine.getInstance().pprint
        ? processor.pprint(data)
        : processor.print(data);
}
set(new Processor('semantic', {
    processor: function (expr) {
        const mml = DomUtil.parseInput(expr);
        return Semantic.xmlTree(mml);
    },
    postprocessor: function (xml, _expr) {
        const setting = Engine.getInstance().speech;
        if (setting === EngineConst.Speech.NONE) {
            return xml;
        }
        const clone = DomUtil.cloneNode(xml);
        let speech = SpeechGeneratorUtil.computeMarkup(clone);
        if (setting === EngineConst.Speech.SHALLOW) {
            xml.setAttribute('speech', AuralRendering.finalize(speech));
            return xml;
        }
        const nodesXml = XpathUtil.evalXPath('.//*[@id]', xml);
        const nodesClone = XpathUtil.evalXPath('.//*[@id]', clone);
        for (let i = 0, orig, node; (orig = nodesXml[i]), (node = nodesClone[i]); i++) {
            speech = SpeechGeneratorUtil.computeMarkup(node);
            orig.setAttribute('speech', AuralRendering.finalize(speech));
        }
        return xml;
    },
    pprint: function (tree) {
        return DomUtil.formatXml(tree.toString());
    }
}));
set(new Processor('speech', {
    processor: function (expr) {
        const mml = DomUtil.parseInput(expr);
        const xml = Semantic.xmlTree(mml);
        const descrs = SpeechGeneratorUtil.computeSpeech(xml);
        return AuralRendering.finalize(AuralRendering.markup(descrs));
    },
    pprint: function (speech) {
        const str = speech.toString();
        return AuralRendering.isXml() ? DomUtil.formatXml(str) : str;
    }
}));
set(new Processor('json', {
    processor: function (expr) {
        const mml = DomUtil.parseInput(expr);
        const stree = Semantic.getTree(mml);
        return stree.toJson();
    },
    postprocessor: function (json, expr) {
        const setting = Engine.getInstance().speech;
        if (setting === EngineConst.Speech.NONE) {
            return json;
        }
        const mml = DomUtil.parseInput(expr);
        const xml = Semantic.xmlTree(mml);
        const speech = SpeechGeneratorUtil.computeMarkup(xml);
        if (setting === EngineConst.Speech.SHALLOW) {
            json.stree.speech = AuralRendering.finalize(speech);
            return json;
        }
        const addRec = (json) => {
            const node = XpathUtil.evalXPath(`.//*[@id=${json.id}]`, xml)[0];
            const speech = SpeechGeneratorUtil.computeMarkup(node);
            json.speech = AuralRendering.finalize(speech);
            if (json.children) {
                json.children.forEach(addRec);
            }
        };
        addRec(json.stree);
        return json;
    },
    print: function (json) {
        return JSON.stringify(json);
    },
    pprint: function (json) {
        return JSON.stringify(json, null, 2);
    }
}));
set(new Processor('description', {
    processor: function (expr) {
        const mml = DomUtil.parseInput(expr);
        const xml = Semantic.xmlTree(mml);
        const descrs = SpeechGeneratorUtil.computeSpeech(xml);
        return descrs;
    },
    print: function (descrs) {
        return JSON.stringify(descrs);
    },
    pprint: function (descrs) {
        return JSON.stringify(descrs, null, 2);
    }
}));
set(new Processor('enriched', {
    processor: function (expr) {
        return Enrich.semanticMathmlSync(expr);
    },
    postprocessor: function (enr, _expr) {
        const root = WalkerUtil.getSemanticRoot(enr);
        let generator;
        switch (Engine.getInstance().speech) {
            case EngineConst.Speech.NONE:
                break;
            case EngineConst.Speech.SHALLOW:
                generator = SpeechGeneratorFactory.generator('Adhoc');
                generator.getSpeech(root, enr);
                break;
            case EngineConst.Speech.DEEP:
                generator = SpeechGeneratorFactory.generator('Tree');
                generator.getSpeech(enr, enr);
                break;
            default:
                break;
        }
        return enr;
    },
    pprint: function (tree) {
        return DomUtil.formatXml(tree.toString());
    }
}));
set(new Processor('rebuild', {
    processor: function (expr) {
        const rebuilt = new RebuildStree(DomUtil.parseInput(expr));
        return rebuilt.stree.xml();
    },
    pprint: function (tree) {
        return DomUtil.formatXml(tree.toString());
    }
}));
set(new Processor('walker', {
    processor: function (expr) {
        const generator = SpeechGeneratorFactory.generator('Node');
        Processor.LocalState.speechGenerator = generator;
        generator.setOptions({
            modality: Engine.getInstance().modality,
            locale: Engine.getInstance().locale,
            domain: Engine.getInstance().domain,
            style: Engine.getInstance().style
        });
        Processor.LocalState.highlighter = HighlighterFactory.highlighter({ color: 'black' }, { color: 'white' }, { renderer: 'NativeMML' });
        const node = process('enriched', expr);
        const eml = print('enriched', node);
        Processor.LocalState.walker = WalkerFactory.walker(Engine.getInstance().walker, node, generator, Processor.LocalState.highlighter, eml);
        return Processor.LocalState.walker;
    },
    print: function (_walker) {
        return Processor.LocalState.walker.speech();
    }
}));
set(new KeyProcessor('move', {
    processor: function (direction) {
        if (!Processor.LocalState.walker) {
            return null;
        }
        const move = Processor.LocalState.walker.move(direction);
        return move === false
            ? AuralRendering.error(direction)
            : Processor.LocalState.walker.speech();
    }
}));
set(new Processor('number', {
    processor: function (numb) {
        const num = parseInt(numb, 10);
        return isNaN(num) ? '' : LOCALE.NUMBERS.numberToWords(num);
    }
}));
set(new Processor('ordinal', {
    processor: function (numb) {
        const num = parseInt(numb, 10);
        return isNaN(num) ? '' : LOCALE.NUMBERS.wordOrdinal(num);
    }
}));
set(new Processor('numericOrdinal', {
    processor: function (numb) {
        const num = parseInt(numb, 10);
        return isNaN(num) ? '' : LOCALE.NUMBERS.numericOrdinal(num);
    }
}));
set(new Processor('vulgar', {
    processor: function (numb) {
        const [en, den] = numb.split('/').map((x) => parseInt(x, 10));
        return isNaN(en) || isNaN(den)
            ? ''
            : process('speech', `<mfrac><mn>${en}</mn><mn>${den}</mn></mfrac>`);
    }
}));
set(new Processor('latex', {
    processor: function (ltx) {
        if (Engine.getInstance().modality !== 'braille' ||
            Engine.getInstance().locale !== 'euro') {
            console.info('LaTeX input currently only works for Euro Braille output.' +
                ' Please use the latex-to-speech package from npm for general' +
                ' LaTeX input to SRE.');
        }
        return process('speech', `<math data-latex="${ltx}"></math>`);
    }
}));
