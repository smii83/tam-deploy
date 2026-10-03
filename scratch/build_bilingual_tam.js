const fs = require('fs');

const jsPath = 'D:/My DOC/project/site/public/assets/index-tam-v5.js';
let js = fs.readFileSync(jsPath, 'utf8');

// Let's inspect where helper functions can be inserted
// We can insert useLang and setSiteLang right before P5()
const p5Target = 'function P5(){';

const langHelperCode = `
function useTamLang() {
  const [lang, setLang] = A.useState(() => {
    try {
      const urlP = new URLSearchParams(window.location.search).get('lang');
      if (urlP === 'en' || urlP === 'ar') return urlP;
      return localStorage.getItem('tam_lang') || 'ar';
    } catch(e) { return 'ar'; }
  });
  A.useEffect(() => {
    const handler = (e) => setLang(e.detail);
    window.addEventListener('tam_lang_change', handler);
    document.documentElement.dir = lang === 'en' ? 'ltr' : 'rtl';
    document.documentElement.lang = lang;
    document.body.style.fontFamily = lang === 'en' ? "'Inter', sans-serif" : "'Cairo', sans-serif";
    return () => window.removeEventListener('tam_lang_change', handler);
  }, [lang]);
  return lang;
}

function toggleTamLang() {
  try {
    const current = localStorage.getItem('tam_lang') || 'ar';
    const next = current === 'ar' ? 'en' : 'ar';
    localStorage.setItem('tam_lang', next);
    document.documentElement.dir = next === 'en' ? 'ltr' : 'rtl';
    document.documentElement.lang = next;
    document.body.style.fontFamily = next === 'en' ? "'Inter', sans-serif" : "'Cairo', sans-serif";
    window.dispatchEvent(new CustomEvent('tam_lang_change', { detail: next }));
  } catch(e) {}
}

`;

console.log('Inserting language helpers before P5...');
js = js.replace(p5Target, langHelperCode + p5Target);

// Now let's inspect and update P5 (Header) to include useTamLang and Language button
// In P5:
const oldP5Body = 'function P5(){const[e,i]=A.useState(!1);return x.jsxs(pt.header';
const newP5Body = `function P5(){const[e,i]=A.useState(!1);const lang=useTamLang();const isEn=lang==='en';const navItems=isEn?[{label:"Features",href:"#features"},{label:"AI Tutor",href:"#ai-tutor"},{label:"Camera Solver",href:"#camera"},{label:"Reviews",href:"#reviews"}]:gv;return x.jsxs(pt.header`;

js = js.replace(oldP5Body, newP5Body);

// In P5 nav mapping:
// gv.map(a=>x.jsx("a",{href:a.href,className:"text-sm font-semibold text-muted-foreground hover:text-primary transition-colors",children:a.label},a.href))
js = js.replace(
  'gv.map(a=>x.jsx("a",{href:a.href,className:"text-sm font-semibold text-muted-foreground hover:text-primary transition-colors",children:a.label},a.href))',
  'navItems.map(a=>x.jsx("a",{href:a.href,className:"text-sm font-semibold text-muted-foreground hover:text-primary transition-colors",children:a.label},a.href))'
);

// In P5 mobile menu nav mapping:
js = js.replace(
  'gv.map(a=>x.jsx("a",{href:a.href,onClick:()=>i(!1),className:"text-sm font-semibold text-muted-foreground hover:text-primary transition-colors py-3 px-2 border-b border-border/40 last:border-0",children:a.label},a.href))',
  'navItems.map(a=>x.jsx("a",{href:a.href,onClick:()=>i(!1),className:"text-sm font-semibold text-muted-foreground hover:text-primary transition-colors py-3 px-2 border-b border-border/40 last:border-0",children:a.label},a.href))'
);

// In P5 right side buttons:
// Add language toggle button in desktop and mobile
const oldP5Buttons = 'x.jsxs("div",{className:"flex items-center gap-3",children:[x.jsxs("a",{href:"#download","data-testid":"link-download-nav"';
const newP5Buttons = 'x.jsxs("div",{className:"flex items-center gap-2 sm:gap-3",children:[x.jsx("button",{onClick:toggleTamLang,className:"flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-border bg-slate-50 hover:bg-slate-100 dark:bg-slate-800 dark:hover:bg-slate-700 text-xs font-bold text-foreground transition-all cursor-pointer shadow-2xs","aria-label":"Toggle Language",children:[x.jsx("span",{className:"text-sm leading-none",children:"🌐"}),x.jsx("span",{className:"leading-none font-bold",children:isEn?"AR":"EN"})]}),x.jsxs("a",{href:"#download","data-testid":"link-download-nav"';

js = js.replace(oldP5Buttons, newP5Buttons);

// Download button text in P5:
js = js.replace(
  'children:[x.jsx(Vf,{size:14}),"حمّل التطبيق"]',
  'children:[x.jsx(Vf,{size:14}),isEn?"Download App":"حمّل التطبيق"]'
);
// In mobile menu download button:
js = js.replace(
  'onClick:()=>i(!1),children:[x.jsx(Vf,{size:14}),"حمّل التطبيق"]',
  'onClick:()=>i(!1),children:[x.jsx(Vf,{size:14}),isEn?"Download App":"حمّل التطبيق"]'
);

// Save updated file
const outPath = 'D:/My DOC/project/site/public/assets/index-tam-v6.js';
fs.writeFileSync(outPath, js, 'utf8');
console.log('Saved index-tam-v6.js successfully!');
