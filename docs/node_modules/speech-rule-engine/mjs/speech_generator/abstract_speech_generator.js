import { setup as EngineSetup } from '../common/engine_setup.js';
import * as EnrichAttr from '../enrich_mathml/enrich_attr.js';
import { RebuildStree } from '../walker/rebuild_stree.js';
import * as SpeechGeneratorUtil from './speech_generator_util.js';
import * as EngineConst from '../common/engine_const.js';
import { LOCALE } from '../l10n/locale.js';
import { ClearspeakPreferences } from '../speech_rules/clearspeak_preferences.js';
export class AbstractSpeechGenerator {
    constructor() {
        this.modality = EnrichAttr.addPrefix('speech');
        this.rebuilt_ = null;
        this.options_ = {};
    }
    getRebuilt() {
        return this.rebuilt_;
    }
    setRebuilt(rebuilt) {
        this.rebuilt_ = rebuilt;
    }
    computeRebuilt(xml, force = false) {
        if (!this.rebuilt_ || force) {
            this.rebuilt_ = new RebuildStree(xml);
        }
        return this.rebuilt_;
    }
    setOptions(options) {
        this.options_ = options || {};
        this.modality = EnrichAttr.addPrefix(this.options_.modality || 'speech');
    }
    setOption(key, value) {
        const options = this.getOptions();
        options[key] = value;
        this.setOptions(options);
    }
    getOptions() {
        return this.options_;
    }
    generateSpeech(_node, xml) {
        if (!this.rebuilt_) {
            this.rebuilt_ = new RebuildStree(xml);
        }
        EngineSetup(this.options_);
        return SpeechGeneratorUtil.computeMarkup(this.getRebuilt().xml);
    }
    nextRules() {
        const options = this.getOptions();
        if (options.modality !== 'speech') {
            return;
        }
        const prefs = ClearspeakPreferences.getLocalePreferences();
        if (!prefs[options.locale]) {
            return;
        }
        EngineConst.DOMAIN_TO_STYLES[options.domain] = options.style;
        options.domain =
            options.domain === 'mathspeak' ? 'clearspeak' : 'mathspeak';
        options.style = EngineConst.DOMAIN_TO_STYLES[options.domain];
        this.setOptions(options);
    }
    nextStyle(id) {
        this.setOption('style', this.nextStyle_(this.getRebuilt().nodeDict[id]));
    }
    nextStyle_(node) {
        const { modality: modality, domain: domain, style: style } = this.getOptions();
        if (modality !== 'speech') {
            return style;
        }
        if (domain === 'mathspeak') {
            const styles = ['default', 'brief', 'sbrief'];
            const index = styles.indexOf(style);
            if (index === -1) {
                return style;
            }
            return index >= styles.length - 1 ? styles[0] : styles[index + 1];
        }
        if (domain === 'clearspeak') {
            const prefs = ClearspeakPreferences.getLocalePreferences();
            const loc = prefs['en'];
            if (!loc) {
                return 'default';
            }
            const smart = ClearspeakPreferences.relevantPreferences(node);
            const current = ClearspeakPreferences.findPreference(style, smart);
            const options = loc[smart].map(function (x) {
                return x.split('_')[1];
            });
            const index = options.indexOf(current);
            if (index === -1) {
                return style;
            }
            const next = index >= options.length - 1 ? options[0] : options[index + 1];
            const result = ClearspeakPreferences.addPreference(style, smart, next);
            return result;
        }
        return style;
    }
    getLevel(depth) {
        return LOCALE.MESSAGES.navigate.LEVEL + ' ' + depth;
    }
    getActionable(actionable) {
        return actionable
            ? actionable < 0
                ? LOCALE.MESSAGES.navigate.EXPANDABLE
                : LOCALE.MESSAGES.navigate.COLLAPSIBLE
            : '';
    }
}
