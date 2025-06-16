import { Engine, SREError } from './engine.js';
import * as EngineConst from '../common/engine_const.js';
import { SystemExternal } from './system_external.js';
import * as XpathUtil from './xpath_util.js';
export function toArray(nodeList) {
    const nodeArray = [];
    for (let i = 0, m = nodeList.length; i < m; i++) {
        nodeArray.push(nodeList[i]);
    }
    return nodeArray;
}
function trimInput(input) {
    input = input.replace(/&nbsp;/g, ' ');
    return input.replace(/>[ \f\n\r\t\v\u200b]+</g, '><').trim();
}
export function parseInput(input) {
    const dp = new SystemExternal.xmldom.DOMParser();
    const clean_input = trimInput(input);
    const allValues = clean_input.match(/&(?!lt|gt|amp|quot|apos)\w+;/g);
    const html = !!allValues;
    if (!clean_input) {
        throw new Error('Empty input!');
    }
    try {
        const doc = dp.parseFromString(clean_input, html ? 'text/html' : 'text/xml');
        if (Engine.getInstance().mode === EngineConst.Mode.HTTP) {
            XpathUtil.xpath.currentDocument = doc;
            return html ? doc.body.childNodes[0] : doc.documentElement;
        }
        return doc.documentElement;
    }
    catch (err) {
        throw new SREError('Illegal input: ' + err.message);
    }
}
export var NodeType;
(function (NodeType) {
    NodeType[NodeType["ELEMENT_NODE"] = 1] = "ELEMENT_NODE";
    NodeType[NodeType["ATTRIBUTE_NODE"] = 2] = "ATTRIBUTE_NODE";
    NodeType[NodeType["TEXT_NODE"] = 3] = "TEXT_NODE";
    NodeType[NodeType["CDATA_SECTION_NODE"] = 4] = "CDATA_SECTION_NODE";
    NodeType[NodeType["ENTITY_REFERENCE_NODE"] = 5] = "ENTITY_REFERENCE_NODE";
    NodeType[NodeType["ENTITY_NODE"] = 6] = "ENTITY_NODE";
    NodeType[NodeType["PROCESSING_INSTRUCTION_NODE"] = 7] = "PROCESSING_INSTRUCTION_NODE";
    NodeType[NodeType["COMMENT_NODE"] = 8] = "COMMENT_NODE";
    NodeType[NodeType["DOCUMENT_NODE"] = 9] = "DOCUMENT_NODE";
    NodeType[NodeType["DOCUMENT_TYPE_NODE"] = 10] = "DOCUMENT_TYPE_NODE";
    NodeType[NodeType["DOCUMENT_FRAGMENT_NODE"] = 11] = "DOCUMENT_FRAGMENT_NODE";
    NodeType[NodeType["NOTATION_NODE"] = 12] = "NOTATION_NODE";
})(NodeType || (NodeType = {}));
export function replaceNode(oldNode, newNode) {
    if (!oldNode.parentNode) {
        return;
    }
    oldNode.parentNode.insertBefore(newNode, oldNode);
    oldNode.parentNode.removeChild(oldNode);
}
export function createElement(tag) {
    return SystemExternal.document.createElement(tag);
}
export function createElementNS(url, tag) {
    return SystemExternal.document.createElementNS(url, tag);
}
export function createTextNode(content) {
    return SystemExternal.document.createTextNode(content);
}
export function formatXml(xml) {
    let formatted = '';
    let reg = /(>)(<)(\/*)/g;
    xml = xml.replace(reg, '$1\r\n$2$3');
    let pad = 0;
    let split = xml.split('\r\n');
    reg = /(\.)*(<)(\/*)/g;
    split = split
        .map((x) => x.replace(reg, '$1\r\n$2$3').split('\r\n'))
        .reduce((x, y) => x.concat(y), []);
    while (split.length) {
        let node = split.shift();
        if (!node) {
            continue;
        }
        let indent = 0;
        if (node.match(/^<\w[^>/]*>[^>]+$/)) {
            const match = matchingStartEnd(node, split[0]);
            if (match[0]) {
                if (match[1]) {
                    node = node + split.shift().slice(0, -match[1].length);
                    if (match[1].trim()) {
                        split.unshift(match[1]);
                    }
                }
                else {
                    node = node + split.shift();
                }
            }
            else {
                indent = 1;
            }
        }
        else if (node.match(/^<\/\w/)) {
            if (pad !== 0) {
                pad -= 1;
            }
        }
        else if (node.match(/^<\w[^>]*[^/]>.*$/)) {
            indent = 1;
        }
        else if (node.match(/^<\w[^>]*\/>.+$/)) {
            const position = node.indexOf('>') + 1;
            const rest = node.slice(position);
            if (rest.trim()) {
                split.unshift();
            }
            node = node.slice(0, position) + rest;
        }
        else {
            indent = 0;
        }
        formatted += new Array(pad + 1).join('  ') + node + '\r\n';
        pad += indent;
    }
    return formatted;
}
function matchingStartEnd(start, end) {
    if (!end) {
        return [false, ''];
    }
    const tag1 = start.match(/^<([^> ]+).*>/);
    const tag2 = end.match(/^<\/([^>]+)>(.*)/);
    return tag1 && tag2 && tag1[1] === tag2[1] ? [true, tag2[2]] : [false, ''];
}
export function querySelectorAllByAttr(node, attr) {
    return node.querySelectorAll
        ? toArray(node.querySelectorAll(`[${attr}]`))
        : XpathUtil.evalXPath(`.//*[@${attr}]`, node);
}
export function querySelectorAllByAttrValue(node, attr, value) {
    return node.querySelectorAll
        ? toArray(node.querySelectorAll(`[${attr}="${value}"]`))
        : XpathUtil.evalXPath(`.//*[@${attr}="${value}"]`, node);
}
export function querySelectorAll(node, tag) {
    return node.querySelectorAll
        ? toArray(node.querySelectorAll(tag))
        : XpathUtil.evalXPath(`.//${tag}`, node);
}
export function tagName(node) {
    return node.tagName.toUpperCase();
}
export function cloneNode(node) {
    return node.cloneNode(true);
}
export function serializeXml(node) {
    const xmls = new SystemExternal.xmldom.XMLSerializer();
    return xmls.serializeToString(node);
}
