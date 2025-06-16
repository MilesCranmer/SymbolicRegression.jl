"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.mapsForIE = void 0;
exports.detectIE = detectIE;
exports.detectEdge = detectEdge;
const system_external_js_1 = require("./system_external.js");
const xpath_util_js_1 = require("./xpath_util.js");
function detectIE() {
    const isIE = typeof window !== 'undefined' &&
        'ActiveXObject' in window &&
        'clipboardData' in window;
    if (!isIE) {
        return false;
    }
    loadMapsForIE();
    loadWGXpath();
    return true;
}
function detectEdge() {
    var _a;
    const isEdge = typeof window !== 'undefined' &&
        'MSGestureEvent' in window &&
        ((_a = window.chrome) === null || _a === void 0 ? void 0 : _a.loadTimes) === null;
    if (!isEdge) {
        return false;
    }
    document.evaluate = null;
    loadWGXpath(true);
    return true;
}
exports.mapsForIE = null;
function loadWGXpath(opt_isEdge) {
    loadScript(system_external_js_1.SystemExternal.WGXpath);
    installWGXpath(opt_isEdge);
}
function installWGXpath(opt_isEdge, opt_count) {
    let count = opt_count || 1;
    if (typeof wgxpath === 'undefined' && count < 10) {
        setTimeout(function () {
            installWGXpath(opt_isEdge, count++);
        }, 200);
        return;
    }
    if (count >= 10) {
        return;
    }
    system_external_js_1.SystemExternal.wgxpath = wgxpath;
    opt_isEdge
        ? system_external_js_1.SystemExternal.wgxpath.install({ document: document })
        : system_external_js_1.SystemExternal.wgxpath.install();
    xpath_util_js_1.xpath.evaluate = document.evaluate;
    xpath_util_js_1.xpath.result = XPathResult;
    xpath_util_js_1.xpath.createNSResolver = document.createNSResolver;
}
function loadMapsForIE() {
    loadScript(system_external_js_1.SystemExternal.mathmapsIePath);
}
function loadScript(src) {
    const scr = system_external_js_1.SystemExternal.document.createElement('script');
    scr.type = 'text/javascript';
    scr.src = src;
    system_external_js_1.SystemExternal.document.head
        ? system_external_js_1.SystemExternal.document.head.appendChild(scr)
        : system_external_js_1.SystemExternal.document.body.appendChild(scr);
}
