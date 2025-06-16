import * as AuralRendering from '../audio/aural_rendering.js';
import * as DomUtil from '../common/dom_util.js';
import * as XpathUtil from '../common/xpath_util.js';
import { Attribute } from '../enrich_mathml/enrich_attr.js';
import { SpeechRuleEngine } from '../rule_engine/speech_rule_engine.js';
import { SemanticTree } from '../semantic_tree/semantic_tree.js';
import * as WalkerUtil from '../walker/walker_util.js';
export function computeSpeech(xml) {
    return SpeechRuleEngine.getInstance().evaluateNode(xml);
}
function recomputeSpeech(semantic) {
    const tree = SemanticTree.fromNode(semantic);
    return computeSpeech(tree.xml());
}
export function computeMarkup(tree) {
    const descrs = computeSpeech(tree);
    return AuralRendering.markup(descrs);
}
export function recomputeMarkup(semantic) {
    const descrs = recomputeSpeech(semantic);
    return AuralRendering.markup(descrs);
}
export function addSpeech(mml, semantic, snode) {
    const sxml = DomUtil.querySelectorAllByAttrValue(snode, 'id', semantic.id.toString())[0];
    const speech = sxml
        ? AuralRendering.markup(computeSpeech(sxml))
        : recomputeMarkup(semantic);
    mml.setAttribute(Attribute.SPEECH, speech);
}
export function addModality(mml, semantic, modality) {
    const markup = recomputeMarkup(semantic);
    mml.setAttribute(modality, markup);
}
export function addPrefix(mml, semantic) {
    const speech = retrievePrefix(semantic);
    if (speech) {
        mml.setAttribute(Attribute.PREFIX, speech);
    }
}
export function retrievePrefix(semantic) {
    const descrs = computePrefix(semantic);
    return AuralRendering.markup(descrs);
}
function computePrefix(semantic) {
    const tree = SemanticTree.fromRoot(semantic);
    const nodes = XpathUtil.evalXPath('.//*[@id="' + semantic.id + '"]', tree.xml());
    let node = nodes[0];
    if (nodes.length > 1) {
        node = nodeAtPosition(semantic, nodes) || node;
    }
    return node
        ? SpeechRuleEngine.getInstance().runInSetting({
            modality: 'prefix',
            domain: 'default',
            style: 'default',
            strict: true,
            speech: true
        }, function () {
            return SpeechRuleEngine.getInstance().evaluateNode(node);
        })
        : [];
}
function nodeAtPosition(semantic, nodes) {
    const node = nodes[0];
    if (!semantic.parent) {
        return node;
    }
    const path = [];
    while (semantic) {
        path.push(semantic.id);
        semantic = semantic.parent;
    }
    const pathEquals = function (xml, path) {
        while (path.length &&
            path.shift().toString() === xml.getAttribute('id') &&
            xml.parentNode &&
            xml.parentNode.parentNode) {
            xml = xml.parentNode.parentNode;
        }
        return !path.length;
    };
    for (let i = 0, xml; (xml = nodes[i]); i++) {
        if (pathEquals(xml, path.slice())) {
            return xml;
        }
    }
    return node;
}
export function connectMactions(node, mml, stree) {
    const mactions = DomUtil.querySelectorAll(mml, 'maction');
    for (let i = 0, maction; (maction = mactions[i]); i++) {
        const aid = maction.getAttribute('id');
        const span = DomUtil.querySelectorAllByAttrValue(node, 'id', aid)[0];
        if (!span) {
            continue;
        }
        const lchild = maction.childNodes[1];
        const mid = lchild.getAttribute(Attribute.ID);
        let cspan = WalkerUtil.getBySemanticId(node, mid);
        if (cspan && cspan.getAttribute(Attribute.TYPE) !== 'dummy') {
            continue;
        }
        cspan = span.childNodes[0];
        if (cspan.getAttribute('sre-highlighter-added')) {
            continue;
        }
        const pid = lchild.getAttribute(Attribute.PARENT);
        if (pid) {
            cspan.setAttribute(Attribute.PARENT, pid);
        }
        cspan.setAttribute(Attribute.TYPE, 'dummy');
        cspan.setAttribute(Attribute.ID, mid);
        cspan.setAttribute('role', 'treeitem');
        cspan.setAttribute('aria-level', lchild.getAttribute('aria-level'));
        const cst = DomUtil.querySelectorAllByAttrValue(stree, 'id', mid)[0];
        cst.setAttribute('alternative', mid);
    }
}
export function connectAllMactions(mml, stree) {
    const mactions = DomUtil.querySelectorAll(mml, 'maction');
    for (let i = 0, maction; (maction = mactions[i]); i++) {
        const lchild = maction.childNodes[1];
        const mid = lchild.getAttribute(Attribute.ID);
        const cst = DomUtil.querySelectorAllByAttrValue(stree, 'id', mid)[0];
        cst.setAttribute('alternative', mid);
    }
}
export function retrieveSummary(node, options = {}) {
    const descrs = computeSummary(node, options);
    return AuralRendering.markup(descrs);
}
function computeSummary(node, options = {}) {
    const preOption = options.locale ? { locale: options.locale } : {};
    return node
        ? SpeechRuleEngine.getInstance().runInSetting(Object.assign(preOption, {
            modality: 'summary',
            strict: false,
            speech: true
        }), function () {
            return SpeechRuleEngine.getInstance().evaluateNode(node);
        })
        : [];
}
