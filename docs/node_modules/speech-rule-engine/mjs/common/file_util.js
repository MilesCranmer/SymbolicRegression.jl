import { SystemExternal } from './system_external.js';
export function makePath(path) {
    return path.match('/$') ? path : path + '/';
}
export function localePath(locale, ext = 'json') {
    return (makePath(SystemExternal.jsonPath) +
        locale +
        (ext.match(/^\./) ? ext : '.' + ext));
}
