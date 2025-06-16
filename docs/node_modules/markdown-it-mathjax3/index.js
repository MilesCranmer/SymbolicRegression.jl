"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
const mathjax_js_1 = require("mathjax-full/js/mathjax.js");
const tex_js_1 = require("mathjax-full/js/input/tex.js");
const svg_js_1 = require("mathjax-full/js/output/svg.js");
const liteAdaptor_js_1 = require("mathjax-full/js/adaptors/liteAdaptor.js");
const html_js_1 = require("mathjax-full/js/handlers/html.js");
const AllPackages_js_1 = require("mathjax-full/js/input/tex/AllPackages.js");
const assistive_mml_js_1 = require("mathjax-full/js/a11y/assistive-mml.js");
const client_1 = __importDefault(require("juice/client"));
function renderMath(content, documentOptions, convertOptions) {
    const adaptor = (0, liteAdaptor_js_1.liteAdaptor)();
    const handler = (0, html_js_1.RegisterHTMLHandler)(adaptor);
    (0, assistive_mml_js_1.AssistiveMmlHandler)(handler);
    const mathDocument = mathjax_js_1.mathjax.document(content, documentOptions);
    const html = adaptor.outerHTML(mathDocument.convert(content, convertOptions));
    const stylesheet = adaptor.outerHTML(documentOptions.OutputJax.styleSheet(mathDocument));
    return (0, client_1.default)(html + stylesheet);
}
// Test if potential opening or closing delimieter
// Assumes that there is a "$" at state.src[pos]
function isValidDelim(state, pos) {
    let max = state.posMax, can_open = true, can_close = true;
    const prevChar = pos > 0 ? state.src.charCodeAt(pos - 1) : -1, nextChar = pos + 1 <= max ? state.src.charCodeAt(pos + 1) : -1;
    // Check non-whitespace conditions for opening and closing, and
    // check that closing delimeter isn't followed by a number
    if (prevChar === 0x20 /* " " */ ||
        prevChar === 0x09 /* \t */ ||
        (nextChar >= 0x30 /* "0" */ && nextChar <= 0x39) /* "9" */) {
        can_close = false;
    }
    if (nextChar === 0x20 /* " " */ || nextChar === 0x09 /* \t */) {
        can_open = false;
    }
    return {
        can_open: can_open,
        can_close: can_close,
    };
}
function math_inline(state, silent) {
    if (state.src[state.pos] !== "$") {
        return false;
    }
    let res = isValidDelim(state, state.pos);
    if (!res.can_open) {
        if (!silent) {
            state.pending += "$";
        }
        state.pos += 1;
        return true;
    }
    // First check for and bypass all properly escaped delimieters
    // This loop will assume that the first leading backtick can not
    // be the first character in state.src, which is known since
    // we have found an opening delimieter already.
    const start = state.pos + 1;
    let match = start;
    while ((match = state.src.indexOf("$", match)) !== -1) {
        // Found potential $, look for escapes, pos will point to
        // first non escape when complete
        let pos = match - 1;
        while (state.src[pos] === "\\") {
            pos -= 1;
        }
        // Even number of escapes, potential closing delimiter found
        if ((match - pos) % 2 == 1) {
            break;
        }
        match += 1;
    }
    // No closing delimter found.  Consume $ and continue.
    if (match === -1) {
        if (!silent) {
            state.pending += "$";
        }
        state.pos = start;
        return true;
    }
    // Check if we have empty content, ie: $$.  Do not parse.
    if (match - start === 0) {
        if (!silent) {
            state.pending += "$$";
        }
        state.pos = start + 1;
        return true;
    }
    // Check for valid closing delimiter
    res = isValidDelim(state, match);
    if (!res.can_close) {
        if (!silent) {
            state.pending += "$";
        }
        state.pos = start;
        return true;
    }
    if (!silent) {
        const token = state.push("math_inline", "math", 0);
        token.markup = "$";
        token.content = state.src.slice(start, match);
    }
    state.pos = match + 1;
    return true;
}
function math_block(state, start, end, silent) {
    let next, lastPos;
    let found = false, pos = state.bMarks[start] + state.tShift[start], max = state.eMarks[start], lastLine = "";
    if (pos + 2 > max) {
        return false;
    }
    if (state.src.slice(pos, pos + 2) !== "$$") {
        return false;
    }
    pos += 2;
    let firstLine = state.src.slice(pos, max);
    if (silent) {
        return true;
    }
    if (firstLine.trim().slice(-2) === "$$") {
        // Single line expression
        firstLine = firstLine.trim().slice(0, -2);
        found = true;
    }
    for (next = start; !found;) {
        next++;
        if (next >= end) {
            break;
        }
        pos = state.bMarks[next] + state.tShift[next];
        max = state.eMarks[next];
        if (pos < max && state.tShift[next] < state.blkIndent) {
            // non-empty line with negative indent should stop the list:
            break;
        }
        if (state.src.slice(pos, max).trim().slice(-2) === "$$") {
            lastPos = state.src.slice(0, max).lastIndexOf("$$");
            lastLine = state.src.slice(pos, lastPos);
            found = true;
        }
    }
    state.line = next + 1;
    const token = state.push("math_block", "math", 0);
    token.block = true;
    token.content =
        (firstLine && firstLine.trim() ? firstLine + "\n" : "") +
            state.getLines(start + 1, next, state.tShift[start], true) +
            (lastLine && lastLine.trim() ? lastLine : "");
    token.map = [start, state.line];
    token.markup = "$$";
    return true;
}
function plugin(md, options) {
    // Default options
    const documentOptions = {
        InputJax: new tex_js_1.TeX(Object.assign({ packages: AllPackages_js_1.AllPackages }, options === null || options === void 0 ? void 0 : options.tex)),
        OutputJax: new svg_js_1.SVG(Object.assign({ fontCache: 'none' }, options === null || options === void 0 ? void 0 : options.svg))
    };
    const convertOptions = {
        display: false
    };
    // set MathJax as the renderer for markdown-it-simplemath
    md.inline.ruler.after("escape", "math_inline", math_inline);
    md.block.ruler.after("blockquote", "math_block", math_block, {
        alt: ["paragraph", "reference", "blockquote", "list"],
    });
    md.renderer.rules.math_inline = function (tokens, idx) {
        convertOptions.display = false;
        return renderMath(tokens[idx].content, documentOptions, convertOptions);
    };
    md.renderer.rules.math_block = function (tokens, idx) {
        convertOptions.display = true;
        return renderMath(tokens[idx].content, documentOptions, convertOptions);
    };
}
;
plugin.default = plugin;
module.exports = plugin;
