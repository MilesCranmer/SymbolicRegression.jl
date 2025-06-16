import * as AudioUtil from './audio_util.js';
import { AuditoryDescription } from './auditory_description.js';
import { XmlRenderer } from './xml_renderer.js';
export declare class LayoutRenderer extends XmlRenderer {
    static options: {
        cayleyshort: boolean;
        linebreaks: boolean;
    };
    finalize(str: string): string;
    pause(_pause: AudioUtil.Pause): string;
    prosodyElement(attr: string, value: number): string;
    closeTag(tag: string): string;
    markup(descrs: AuditoryDescription[]): string;
    private processContent;
    private values;
    private layoutValue;
}
