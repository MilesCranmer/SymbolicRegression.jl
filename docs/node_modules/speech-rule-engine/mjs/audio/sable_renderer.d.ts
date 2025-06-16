import * as EngineConst from '../common/engine_const.js';
import { Pause } from './audio_util.js';
import { XmlRenderer } from './xml_renderer.js';
export declare class SableRenderer extends XmlRenderer {
    finalize(str: string): string;
    pause(pause: Pause): string;
    prosodyElement(tag: EngineConst.personalityProps, value: number): string;
    closeTag(tag: string): string;
}
