import { EnginePromise } from './engine.js';
import * as EngineConst from '../common/engine_const.js';
import * as System from './system.js';
(function () {
    const SIGNAL = MathJax.Callback.Signal('Sre');
    MathJax.Extension.Sre = {
        version: System.version,
        signal: SIGNAL,
        ConfigSre: function () {
            EnginePromise.getall().then(() => MathJax.Callback.Queue(MathJax.Hub.Register.StartupHook('mml Jax Ready', {}), ['Post', MathJax.Hub.Startup.signal, 'Sre Ready']));
        }
    };
    System.setupEngine({
        mode: EngineConst.Mode.HTTP,
        json: MathJax.Ajax.config.path['SRE'] + '/mathmaps',
        xpath: MathJax.Ajax.config.path['SRE'] + '/wgxpath.install.js',
        semantics: true
    });
    MathJax.Extension.Sre.ConfigSre();
})();
