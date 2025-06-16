import { AbstractWalker } from './abstract_walker.js';
export class DummyWalker extends AbstractWalker {
    up() {
        return null;
    }
    down() {
        return null;
    }
    left() {
        return null;
    }
    right() {
        return null;
    }
    repeat() {
        return null;
    }
    depth() {
        return null;
    }
    home() {
        return null;
    }
    getDepth() {
        return 0;
    }
    initLevels() {
        return null;
    }
    combineContentChildren(_type, _role, _content, _children) {
        return [];
    }
    findFocusOnLevel(_id) {
        return null;
    }
}
