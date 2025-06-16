"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AbstractWalker = void 0;
const auditory_description_js_1 = require("../audio/auditory_description.js");
const AuralRendering = require("../audio/aural_rendering.js");
const DomUtil = require("../common/dom_util.js");
const engine_setup_js_1 = require("../common/engine_setup.js");
const event_util_js_1 = require("../common/event_util.js");
const enrich_attr_js_1 = require("../enrich_mathml/enrich_attr.js");
const locale_js_1 = require("../l10n/locale.js");
const grammar_js_1 = require("../rule_engine/grammar.js");
const semantic_skeleton_js_1 = require("../semantic_tree/semantic_skeleton.js");
const SpeechGeneratorFactory = require("../speech_generator/speech_generator_factory.js");
const SpeechGeneratorUtil = require("../speech_generator/speech_generator_util.js");
const focus_js_1 = require("./focus.js");
const rebuild_stree_js_1 = require("./rebuild_stree.js");
const walker_js_1 = require("./walker.js");
const WalkerUtil = require("./walker_util.js");
const XpathUtil = require("../common/xpath_util.js");
class AbstractWalker {
    constructor(node, generator, highlighter, xml) {
        this.node = node;
        this.generator = generator;
        this.highlighter = highlighter;
        this.modifier = false;
        this.keyMapping = new Map([
            [event_util_js_1.KeyCode.UP, this.up.bind(this)],
            [event_util_js_1.KeyCode.DOWN, this.down.bind(this)],
            [event_util_js_1.KeyCode.RIGHT, this.right.bind(this)],
            [event_util_js_1.KeyCode.LEFT, this.left.bind(this)],
            [event_util_js_1.KeyCode.TAB, this.repeat.bind(this)],
            [event_util_js_1.KeyCode.DASH, this.expand.bind(this)],
            [event_util_js_1.KeyCode.SPACE, this.depth.bind(this)],
            [event_util_js_1.KeyCode.HOME, this.home.bind(this)],
            [event_util_js_1.KeyCode.X, this.summary.bind(this)],
            [event_util_js_1.KeyCode.Z, this.detail.bind(this)],
            [event_util_js_1.KeyCode.V, this.virtualize.bind(this)],
            [event_util_js_1.KeyCode.P, this.previous.bind(this)],
            [event_util_js_1.KeyCode.U, this.undo.bind(this)],
            [event_util_js_1.KeyCode.LESS, this.previousRules.bind(this)],
            [event_util_js_1.KeyCode.GREATER, this.nextRules.bind(this)]
        ]);
        this.cursors = [];
        this.xml_ = null;
        this.rebuilt_ = null;
        this.focus_ = null;
        this.active_ = false;
        if (this.node.id) {
            this.id = this.node.id;
        }
        else if (this.node.hasAttribute(AbstractWalker.SRE_ID_ATTR)) {
            this.id = this.node.getAttribute(AbstractWalker.SRE_ID_ATTR);
        }
        else {
            this.node.setAttribute(AbstractWalker.SRE_ID_ATTR, AbstractWalker.ID_COUNTER.toString());
            this.id = AbstractWalker.ID_COUNTER++;
        }
        this.rootNode = WalkerUtil.getSemanticRoot(node);
        this.rootId = this.rootNode.getAttribute(enrich_attr_js_1.Attribute.ID);
        this.xmlString_ = xml;
        this.moved = walker_js_1.WalkerMoves.ENTER;
    }
    getXml() {
        if (!this.xml_) {
            this.xml_ = DomUtil.parseInput(this.xmlString_);
        }
        return this.xml_;
    }
    getRebuilt() {
        if (!this.rebuilt_) {
            this.rebuildStree();
        }
        return this.rebuilt_;
    }
    isActive() {
        return this.active_;
    }
    activate() {
        if (this.isActive()) {
            return;
        }
        this.toggleActive_();
    }
    deactivate() {
        if (!this.isActive()) {
            return;
        }
        walker_js_1.WalkerState.setState(this.id, this.primaryId());
        this.toggleActive_();
    }
    getFocus(update = false) {
        if (this.rootId === null) {
            this.getRebuilt();
        }
        if (!this.focus_) {
            this.focus_ = this.singletonFocus(this.rootId);
        }
        if (update) {
            this.updateFocus();
        }
        return this.focus_;
    }
    setFocus(focus) {
        this.focus_ = focus;
    }
    getDepth() {
        return this.levels.depth() - 1;
    }
    isSpeech() {
        return this.generator.modality === enrich_attr_js_1.Attribute.SPEECH;
    }
    focusDomNodes() {
        return this.getFocus().getDomNodes();
    }
    focusSemanticNodes() {
        return this.getFocus().getSemanticNodes();
    }
    speech() {
        const nodes = this.focusDomNodes();
        if (!nodes.length) {
            return '';
        }
        const special = this.specialMove();
        if (special !== null) {
            return special;
        }
        switch (this.moved) {
            case walker_js_1.WalkerMoves.DEPTH:
                return this.depth_();
            case walker_js_1.WalkerMoves.SUMMARY:
                return this.summary_();
            case walker_js_1.WalkerMoves.DETAIL:
                return this.detail_();
            default: {
                const speech = [];
                const snodes = this.focusSemanticNodes();
                for (let i = 0, l = nodes.length; i < l; i++) {
                    const node = nodes[i];
                    const snode = snodes[i];
                    speech.push(node
                        ? this.generator.getSpeech(node, this.getXml(), this.node)
                        : SpeechGeneratorUtil.recomputeMarkup(snode));
                }
                return this.mergePrefix_(speech);
            }
        }
    }
    move(key) {
        const direction = this.keyMapping.get(key);
        if (!direction) {
            return null;
        }
        const focus = direction();
        if (!focus || focus === this.getFocus()) {
            return false;
        }
        this.setFocus(focus);
        if (this.moved === walker_js_1.WalkerMoves.HOME) {
            this.levels = this.initLevels();
        }
        return true;
    }
    up() {
        this.moved = walker_js_1.WalkerMoves.UP;
        return this.getFocus();
    }
    down() {
        this.moved = walker_js_1.WalkerMoves.DOWN;
        return this.getFocus();
    }
    left() {
        this.moved = walker_js_1.WalkerMoves.LEFT;
        return this.getFocus();
    }
    right() {
        this.moved = walker_js_1.WalkerMoves.RIGHT;
        return this.getFocus();
    }
    repeat() {
        this.moved = walker_js_1.WalkerMoves.REPEAT;
        return this.getFocus().clone();
    }
    depth() {
        this.moved = this.isSpeech() ? walker_js_1.WalkerMoves.DEPTH : walker_js_1.WalkerMoves.REPEAT;
        return this.getFocus().clone();
    }
    home() {
        this.moved = walker_js_1.WalkerMoves.HOME;
        const focus = this.singletonFocus(this.rootId);
        return focus;
    }
    getBySemanticId(id) {
        return WalkerUtil.getBySemanticId(this.node, id);
    }
    primaryId() {
        return this.getFocus().getSemanticPrimary().id.toString();
    }
    expand() {
        const primary = this.getFocus().getDomPrimary();
        const expandable = this.actionable_(primary);
        if (!expandable) {
            return this.getFocus();
        }
        this.moved = walker_js_1.WalkerMoves.EXPAND;
        expandable.dispatchEvent(new Event('click'));
        return this.getFocus().clone();
    }
    expandable(node) {
        const parent = !!this.actionable_(node);
        return parent && node.childNodes.length === 0;
    }
    collapsible(node) {
        const parent = !!this.actionable_(node);
        return parent && node.childNodes.length > 0;
    }
    restoreState() {
        if (!this.highlighter) {
            return;
        }
        const state = walker_js_1.WalkerState.getState(this.id);
        if (!state) {
            return;
        }
        let node = this.getRebuilt().nodeDict[state];
        const path = [];
        while (node) {
            path.push(node.id);
            node = node.parent;
        }
        path.pop();
        while (path.length > 0) {
            this.down();
            const id = path.pop();
            const focus = this.findFocusOnLevel(id);
            if (!focus) {
                break;
            }
            this.setFocus(focus);
        }
        this.moved = walker_js_1.WalkerMoves.ENTER;
    }
    updateFocus() {
        this.setFocus(focus_js_1.Focus.factory(this.getFocus().getSemanticPrimary().id.toString(), this.getFocus()
            .getSemanticNodes()
            .map((x) => x.id.toString()), this.getRebuilt(), this.node));
    }
    rebuildStree() {
        this.rebuilt_ = new rebuild_stree_js_1.RebuildStree(this.getXml());
        this.rootId = this.rebuilt_.stree.root.id.toString();
        this.generator.setRebuilt(this.rebuilt_);
        this.skeleton = semantic_skeleton_js_1.SemanticSkeleton.fromTree(this.rebuilt_.stree);
        this.skeleton.populate();
        this.focus_ = this.singletonFocus(this.rootId);
        this.levels = this.initLevels();
        SpeechGeneratorUtil.connectMactions(this.node, this.getXml(), this.rebuilt_.xml);
    }
    previousLevel() {
        const dnode = this.getFocus().getDomPrimary();
        return dnode
            ? WalkerUtil.getAttribute(dnode, enrich_attr_js_1.Attribute.PARENT)
            : this.getFocus().getSemanticPrimary().parent.id.toString();
    }
    nextLevel() {
        const dnode = this.getFocus().getDomPrimary();
        let children;
        let content;
        if (dnode) {
            children = WalkerUtil.splitAttribute(WalkerUtil.getAttribute(dnode, enrich_attr_js_1.Attribute.CHILDREN));
            content = WalkerUtil.splitAttribute(WalkerUtil.getAttribute(dnode, enrich_attr_js_1.Attribute.CONTENT));
            const type = WalkerUtil.getAttribute(dnode, enrich_attr_js_1.Attribute.TYPE);
            const role = WalkerUtil.getAttribute(dnode, enrich_attr_js_1.Attribute.ROLE);
            return this.combineContentChildren(type, role, content, children);
        }
        const toIds = (x) => x.id.toString();
        const snode = this.getRebuilt().nodeDict[this.primaryId()];
        children = snode.childNodes.map(toIds);
        content = snode.contentNodes.map(toIds);
        if (children.length === 0) {
            return [];
        }
        return this.combineContentChildren(snode.type, snode.role, content, children);
    }
    singletonFocus(id) {
        this.getRebuilt();
        const ids = this.retrieveVisuals(id);
        return this.focusFromId(id, ids);
    }
    retrieveVisuals(id) {
        if (!this.skeleton) {
            return [id];
        }
        const num = parseInt(id, 10);
        const semStree = this.skeleton.subtreeNodes(num);
        if (!semStree.length) {
            return [id];
        }
        semStree.unshift(num);
        const mmlStree = {};
        const result = [];
        XpathUtil.updateEvaluator(this.getXml());
        for (const child of semStree) {
            if (mmlStree[child]) {
                continue;
            }
            result.push(child.toString());
            mmlStree[child] = true;
            this.subtreeIds(child, mmlStree);
        }
        return result;
    }
    subtreeIds(id, nodes) {
        const xmlRoot = XpathUtil.evalXPath(`//*[@data-semantic-id="${id}"]`, this.getXml());
        const xpath = XpathUtil.evalXPath('*//@data-semantic-id', xmlRoot[0]);
        xpath.forEach((x) => (nodes[parseInt(x.textContent, 10)] = true));
    }
    focusFromId(id, ids) {
        return focus_js_1.Focus.factory(id, ids, this.getRebuilt(), this.node);
    }
    summary() {
        this.moved = this.isSpeech() ? walker_js_1.WalkerMoves.SUMMARY : walker_js_1.WalkerMoves.REPEAT;
        return this.getFocus().clone();
    }
    detail() {
        this.moved = this.isSpeech() ? walker_js_1.WalkerMoves.DETAIL : walker_js_1.WalkerMoves.REPEAT;
        return this.getFocus().clone();
    }
    specialMove() {
        return null;
    }
    virtualize(opt_undo) {
        this.cursors.push({
            focus: this.getFocus(),
            levels: this.levels,
            undo: opt_undo || !this.cursors.length
        });
        this.levels = this.levels.clone();
        return this.getFocus().clone();
    }
    previous() {
        const previous = this.cursors.pop();
        if (!previous) {
            return this.getFocus();
        }
        this.levels = previous.levels;
        return previous.focus;
    }
    undo() {
        let previous;
        do {
            previous = this.cursors.pop();
        } while (previous && !previous.undo);
        if (!previous) {
            return this.getFocus();
        }
        this.levels = previous.levels;
        return previous.focus;
    }
    update(options) {
        (0, engine_setup_js_1.setup)(options).then(() => SpeechGeneratorFactory.generator('Tree').getSpeech(this.node, this.getXml()));
    }
    nextRules() {
        this.generator.nextRules();
        const options = this.generator.getOptions();
        if (options.modality !== 'speech') {
            return this.getFocus();
        }
        this.update(options);
        this.moved = walker_js_1.WalkerMoves.REPEAT;
        return this.getFocus().clone();
    }
    previousRules() {
        var _a;
        this.generator.nextStyle((_a = this.getFocus().getSemanticPrimary()) === null || _a === void 0 ? void 0 : _a.id.toString());
        const options = this.generator.getOptions();
        if (options.modality !== 'speech') {
            return this.getFocus();
        }
        this.update(options);
        this.moved = walker_js_1.WalkerMoves.REPEAT;
        return this.getFocus().clone();
    }
    refocus() {
        let focus = this.getFocus();
        let last;
        while (!focus.getNodes().length) {
            last = this.levels.peek();
            const up = this.up();
            if (!up) {
                break;
            }
            this.setFocus(up);
            focus = this.getFocus(true);
        }
        this.levels.push(last);
        this.setFocus(focus);
    }
    toggleActive_() {
        this.active_ = !this.active_;
    }
    mergePrefix_(speech, pre = []) {
        const prefix = this.isSpeech() ? this.prefix_() : '';
        if (prefix) {
            speech.unshift(prefix);
        }
        const postfix = this.isSpeech() ? this.postfix_() : '';
        if (postfix) {
            speech.push(postfix);
        }
        return AuralRendering.finalize(AuralRendering.merge(pre.concat(speech)));
    }
    prefix_() {
        const nodes = this.getFocus().getDomNodes();
        const snodes = this.getFocus().getSemanticNodes();
        return nodes[0]
            ? WalkerUtil.getAttribute(nodes[0], enrich_attr_js_1.Attribute.PREFIX)
            : SpeechGeneratorUtil.retrievePrefix(snodes[0]);
    }
    postfix_() {
        const nodes = this.getFocus().getDomNodes();
        return nodes[0]
            ? WalkerUtil.getAttribute(nodes[0], enrich_attr_js_1.Attribute.POSTFIX)
            : '';
    }
    depth_() {
        const oldDepth = grammar_js_1.Grammar.getInstance().getParameter('depth');
        grammar_js_1.Grammar.getInstance().setParameter('depth', true);
        const primary = this.getFocus().getDomPrimary();
        const expand = this.expandable(primary)
            ? locale_js_1.LOCALE.MESSAGES.navigate.EXPANDABLE
            : this.collapsible(primary)
                ? locale_js_1.LOCALE.MESSAGES.navigate.COLLAPSIBLE
                : '';
        const level = locale_js_1.LOCALE.MESSAGES.navigate.LEVEL + ' ' + this.getDepth();
        const snodes = this.getFocus().getSemanticNodes();
        const prefix = SpeechGeneratorUtil.retrievePrefix(snodes[0]);
        const audio = [
            new auditory_description_js_1.AuditoryDescription({ text: level, personality: {} }),
            new auditory_description_js_1.AuditoryDescription({ text: prefix, personality: {} }),
            new auditory_description_js_1.AuditoryDescription({ text: expand, personality: {} })
        ];
        grammar_js_1.Grammar.getInstance().setParameter('depth', oldDepth);
        return AuralRendering.finalize(AuralRendering.markup(audio));
    }
    actionable_(node) {
        const parent = node === null || node === void 0 ? void 0 : node.parentNode;
        return parent && this.highlighter.isMactionNode(parent) ? parent : null;
    }
    summary_() {
        const sprimary = this.getFocus().getSemanticPrimary();
        const sid = sprimary.id.toString();
        const snode = this.getRebuilt().xml.getAttribute('id') === sid
            ? this.getRebuilt().xml
            : DomUtil.querySelectorAllByAttrValue(this.getRebuilt().xml, 'id', sid)[0];
        const summary = SpeechGeneratorUtil.retrieveSummary(snode);
        const speech = this.mergePrefix_([summary]);
        return speech;
    }
    detail_() {
        const sprimary = this.getFocus().getSemanticPrimary();
        const sid = sprimary.id.toString();
        const snode = this.getRebuilt().xml.getAttribute('id') === sid
            ? this.getRebuilt().xml
            : DomUtil.querySelectorAllByAttrValue(this.getRebuilt().xml, 'id', sid)[0];
        const oldAlt = snode.getAttribute('alternative');
        snode.removeAttribute('alternative');
        const detail = SpeechGeneratorUtil.computeMarkup(snode);
        const speech = this.mergePrefix_([detail]);
        snode.setAttribute('alternative', oldAlt);
        return speech;
    }
}
exports.AbstractWalker = AbstractWalker;
AbstractWalker.ID_COUNTER = 0;
AbstractWalker.SRE_ID_ATTR = 'sre-explorer-id';
