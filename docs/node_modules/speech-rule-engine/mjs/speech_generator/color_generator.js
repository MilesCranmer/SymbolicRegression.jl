import * as DomUtil from '../common/dom_util.js';
import { addPrefix } from '../enrich_mathml/enrich_attr.js';
import { ContrastPicker } from '../highlighter/color_picker.js';
import { RebuildStree } from '../walker/rebuild_stree.js';
import * as WalkerUtil from '../walker/walker_util.js';
import { AbstractSpeechGenerator } from './abstract_speech_generator.js';
export class ColorGenerator extends AbstractSpeechGenerator {
    constructor() {
        super(...arguments);
        this.modality = addPrefix('foreground');
        this.contrast = new ContrastPicker();
    }
    static visitStree_(tree, leaves, ignore) {
        if (!tree.childNodes.length) {
            if (!ignore[tree.id]) {
                leaves.push(tree.id);
            }
            return;
        }
        if (tree.contentNodes.length) {
            if (tree.type === 'punctuated') {
                tree.contentNodes.forEach((x) => (ignore[x.id] = true));
            }
            if (tree.role !== 'implicit') {
                leaves.push(tree.contentNodes.map((x) => x.id));
            }
        }
        if (tree.childNodes.length) {
            if (tree.role === 'implicit') {
                const factors = [];
                let rest = [];
                for (const child of tree.childNodes) {
                    const tt = [];
                    ColorGenerator.visitStree_(child, tt, ignore);
                    if (tt.length <= 2) {
                        factors.push(tt.shift());
                    }
                    rest = rest.concat(tt);
                }
                leaves.push(factors);
                rest.forEach((x) => leaves.push(x));
                return;
            }
            tree.childNodes.forEach((x) => ColorGenerator.visitStree_(x, leaves, ignore));
        }
    }
    getSpeech(node, _xml) {
        return WalkerUtil.getAttribute(node, this.modality);
    }
    generateSpeech(node, xml) {
        if (!this.getRebuilt()) {
            this.setRebuilt(new RebuildStree(DomUtil.parseInput(xml)));
        }
        this.colorLeaves_(node);
        return WalkerUtil.getAttribute(node, this.modality);
    }
    colorLeaves_(node) {
        const leaves = [];
        ColorGenerator.visitStree_(this.getRebuilt().streeRoot, leaves, {});
        for (const id of leaves) {
            const color = this.contrast.generate();
            let success = false;
            if (Array.isArray(id)) {
                success = id
                    .map((x) => this.colorLeave_(node, x, color))
                    .reduce((x, y) => x || y, false);
            }
            else {
                success = this.colorLeave_(node, id.toString(), color);
            }
            if (success) {
                this.contrast.increment();
            }
        }
    }
    colorLeave_(node, id, color) {
        const aux = WalkerUtil.getBySemanticId(node, id);
        if (aux) {
            aux.setAttribute(this.modality, color);
            return true;
        }
        return false;
    }
}
