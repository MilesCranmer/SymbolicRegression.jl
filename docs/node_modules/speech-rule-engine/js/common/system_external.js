"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SystemExternal = void 0;
const variables_js_1 = require("./variables.js");
class SystemExternal {
    static nodeRequire() {
        return eval('require');
    }
    static extRequire(library) {
        if (typeof process !== 'undefined' && typeof require !== 'undefined') {
            return SystemExternal.nodeRequire()(library);
        }
        return null;
    }
}
exports.SystemExternal = SystemExternal;
SystemExternal.windowSupported = (() => !(typeof window === 'undefined'))();
SystemExternal.documentSupported = (() => SystemExternal.windowSupported &&
    !(typeof window.document === 'undefined'))();
SystemExternal.xmldom = SystemExternal.documentSupported
    ? window
    : SystemExternal.extRequire('@xmldom/xmldom');
SystemExternal.document = SystemExternal.documentSupported
    ? window.document
    : new SystemExternal.xmldom.DOMImplementation().createDocument('', '', 0);
SystemExternal.xpath = SystemExternal.documentSupported
    ? document
    : (function () {
        const window = { document: {}, XPathResult: {} };
        const wgx = SystemExternal.extRequire('wicked-good-xpath');
        wgx.install(window);
        window.document.XPathResult = window.XPathResult;
        return window.document;
    })();
SystemExternal.mathmapsIePath = 'https://cdn.jsdelivr.net/npm/sre-mathmaps-ie@' +
    variables_js_1.Variables.VERSION +
    'mathmaps_ie.js';
SystemExternal.fs = SystemExternal.documentSupported
    ? null
    : SystemExternal.extRequire('fs');
SystemExternal.url = variables_js_1.Variables.url;
SystemExternal.jsonPath = (function () {
    if (SystemExternal.documentSupported) {
        return SystemExternal.url;
    }
    if (process.env.SRE_JSON_PATH || global.SRE_JSON_PATH) {
        return process.env.SRE_JSON_PATH || global.SRE_JSON_PATH;
    }
    try {
        const path = SystemExternal.nodeRequire().resolve('speech-rule-engine');
        return path.replace(/sre\.js$/, '') + 'mathmaps';
    }
    catch (_err) {
    }
    try {
        const path = SystemExternal.nodeRequire().resolve('.');
        return path.replace(/sre\.js$/, '') + 'mathmaps';
    }
    catch (_err) {
    }
    return typeof __dirname !== 'undefined'
        ? __dirname + (__dirname.match(/lib?$/) ? '/mathmaps' : '/lib/mathmaps')
        : process.cwd() + '/lib/mathmaps';
})();
SystemExternal.WGXpath = variables_js_1.Variables.WGXpath;
SystemExternal.wgxpath = null;
exports.default = SystemExternal;
