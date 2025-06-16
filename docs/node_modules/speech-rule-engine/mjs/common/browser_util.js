import { SystemExternal } from './system_external.js';
import { xpath } from './xpath_util.js';
export function detectIE() {
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
export function detectEdge() {
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
export const mapsForIE = null;
function loadWGXpath(opt_isEdge) {
    loadScript(SystemExternal.WGXpath);
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
    SystemExternal.wgxpath = wgxpath;
    opt_isEdge
        ? SystemExternal.wgxpath.install({ document: document })
        : SystemExternal.wgxpath.install();
    xpath.evaluate = document.evaluate;
    xpath.result = XPathResult;
    xpath.createNSResolver = document.createNSResolver;
}
function loadMapsForIE() {
    loadScript(SystemExternal.mathmapsIePath);
}
function loadScript(src) {
    const scr = SystemExternal.document.createElement('script');
    scr.type = 'text/javascript';
    scr.src = src;
    SystemExternal.document.head
        ? SystemExternal.document.head.appendChild(scr)
        : SystemExternal.document.body.appendChild(scr);
}
