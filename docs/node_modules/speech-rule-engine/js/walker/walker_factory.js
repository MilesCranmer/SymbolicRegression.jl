"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.walker = walker;
const dummy_walker_js_1 = require("./dummy_walker.js");
const semantic_walker_js_1 = require("./semantic_walker.js");
const syntax_walker_js_1 = require("./syntax_walker.js");
const table_walker_js_1 = require("./table_walker.js");
function walker(type, node, generator, highlighter, xml) {
    const constructor = walkerMapping[type.toLowerCase()] || walkerMapping['dummy'];
    return constructor(node, generator, highlighter, xml);
}
const walkerMapping = {
    dummy: (p1, p2, p3, p4) => new dummy_walker_js_1.DummyWalker(p1, p2, p3, p4),
    semantic: (p1, p2, p3, p4) => new semantic_walker_js_1.SemanticWalker(p1, p2, p3, p4),
    syntax: (p1, p2, p3, p4) => new syntax_walker_js_1.SyntaxWalker(p1, p2, p3, p4),
    table: (p1, p2, p3, p4) => new table_walker_js_1.TableWalker(p1, p2, p3, p4)
};
