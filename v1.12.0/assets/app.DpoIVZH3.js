import{T as p}from"./chunks/theme.bYgCZWQU.js";import{R as s,an as i,ao as u,ap as c,aq as l,ar as f,as as d,at as m,au as h,av as g,aw as A,d as v,u as y,v as w,s as C,ax as P,ay as R,az as T,am as b}from"./chunks/framework.BUNNcBMr.js";function r(e){if(e.extends){const a=r(e.extends);return{...a,...e,async enhanceApp(t){a.enhanceApp&&await a.enhanceApp(t),e.enhanceApp&&await e.enhanceApp(t)}}}return e}const __adjustVitepressBase = (siteData) => {
  if (typeof window === 'undefined') return;
  if (!siteData || typeof siteData.base !== 'string') return;
  const pathname = window.location && typeof window.location.pathname === 'string' ? window.location.pathname : null;
  if (!pathname) return;
  const normalize = (value) => value.replace(/^\/+|\/+$/g, '').split('/');
  const original = normalize(siteData.base);
  const current = normalize(pathname);
  if (original.length >= 2 && current.length >= 2 && original[0] === current[0] && original[1] !== current[1]) {
    const newBase = `/${current[0]}/${current[1]}/`;
    siteData.base = newBase;
    const theme = siteData.themeConfig || {};
    const logo = theme.logo && typeof theme.logo === 'object' ? Object.assign({}, theme.logo) : { width: 24, height: 24 };
    logo.src = `${newBase}logo.png`;
    theme.logo = logo;
    siteData.themeConfig = theme;
  }
};
if (typeof window !== "undefined") {
  if (window.__VP_SITE_DATA__) {
    __adjustVitepressBase(window.__VP_SITE_DATA__);
  } else {
    Object.defineProperty(window, "__VP_SITE_DATA__", {
      configurable: true,
      set(value) {
        __adjustVitepressBase(value);
        Object.defineProperty(window, "__VP_SITE_DATA__", { value, writable: true, configurable: true });
      }
    });
  }
}
const n=r(p),E=v({name:"VitePressApp",setup(){const{site:e,lang:a,dir:t}=y();return w(()=>{C(()=>{document.documentElement.lang=a.value,document.documentElement.dir=t.value})}),e.value.router.prefetchLinks&&P(),R(),T(),n.setup&&n.setup(),()=>b(n.Layout)}});async function S(){globalThis.__VITEPRESS__=!0;const e=D(),a=x();a.provide(u,e);const t=c(e.route);return a.provide(l,t),__adjustVitepressBase(m),a.component("Content",f),a.component("ClientOnly",d),Object.defineProperties(a.config.globalProperties,{$frontmatter:{get(){return t.frontmatter.value}},$params:{get(){return t.page.value.params}}}),n.enhanceApp&&await n.enhanceApp({app:a,router:e,siteData:m}),{app:a,router:e,data:t}}function x(){return A(E)}function D(){let e=s;return h(a=>{let t=g(a),o=null;return t&&(e&&(t=t.replace(/\.js$/,".lean.js")),o=import(t)),s&&(e=!1),o},n.NotFound)}s&&S().then(({app:e,router:a,data:t})=>{a.go().then(()=>{i(a.route,t.site),e.mount("#app")})});export{S as createApp};
