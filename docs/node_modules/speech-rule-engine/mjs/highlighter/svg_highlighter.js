import * as DomUtil from '../common/dom_util.js';
import { AbstractHighlighter } from './abstract_highlighter.js';
export class SvgHighlighter extends AbstractHighlighter {
    constructor() {
        super();
        this.mactionName = 'mjx-svg-maction';
    }
    highlightNode(node) {
        let info;
        if (this.isHighlighted(node)) {
            info = {
                node: node.previousSibling || node,
                background: node.style.backgroundColor,
                foreground: node.style.color
            };
            return info;
        }
        if (node.tagName === 'svg') {
            const info = {
                node: node,
                background: node.style.backgroundColor,
                foreground: node.style.color
            };
            node.style.backgroundColor = this.colorString().background;
            node.style.color = this.colorString().foreground;
            return info;
        }
        const rect = DomUtil.createElementNS('http://www.w3.org/2000/svg', 'rect');
        const padding = 40;
        let bbox;
        if (node.nodeName === 'use') {
            const g = DomUtil.createElementNS('http://www.w3.org/2000/svg', 'g');
            node.parentNode.insertBefore(g, node);
            g.appendChild(node);
            bbox = g.getBBox();
            g.parentNode.replaceChild(node, g);
        }
        else {
            bbox = node.getBBox();
        }
        rect.setAttribute('x', (bbox.x - padding).toString());
        rect.setAttribute('y', (bbox.y - padding).toString());
        rect.setAttribute('width', (bbox.width + 2 * padding).toString());
        rect.setAttribute('height', (bbox.height + 2 * padding).toString());
        const transform = node.getAttribute('transform');
        if (transform) {
            rect.setAttribute('transform', transform);
        }
        rect.setAttribute('fill', this.colorString().background);
        rect.setAttribute(this.ATTR, 'true');
        node.parentNode.insertBefore(rect, node);
        info = { node: rect, foreground: node.getAttribute('fill') };
        node.setAttribute('fill', this.colorString().foreground);
        return info;
    }
    setHighlighted(node) {
        if (node.tagName === 'svg') {
            super.setHighlighted(node);
        }
    }
    unhighlightNode(info) {
        if ('background' in info) {
            info.node.style.backgroundColor = info.background;
            info.node.style.color = info.foreground;
            return;
        }
        info.foreground
            ? info.node.nextSibling.setAttribute('fill', info.foreground)
            : info.node.nextSibling.removeAttribute('fill');
        info.node.parentNode.removeChild(info.node);
    }
    isMactionNode(node) {
        let className = node.className || node.getAttribute('class');
        if (!className) {
            return false;
        }
        className =
            className.baseVal !== undefined
                ? className.baseVal
                : className;
        return className ? !!className.match(new RegExp(this.mactionName)) : false;
    }
}
