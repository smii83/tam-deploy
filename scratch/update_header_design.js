const fs = require('fs');

const jsPath = 'D:/My DOC/project/site/public/assets/index-tam-v8.js';
let js = fs.readFileSync(jsPath, 'utf8');

// 1. Update gv definition with Privacy and Terms
const oldGv = 'gv=[{label:"الميزات",href:"#features"},{label:"المدرس الذكي",href:"#ai-tutor"},{label:"حل بالكاميرا",href:"#camera"},{label:"آراء الطلاب",href:"#reviews"}]';
const newGv = 'gv=[{label:"الميزات",href:"#features"},{label:"المدرس الذكي",href:"#ai-tutor"},{label:"حل بالكاميرا",href:"#camera"},{label:"آراء الطلاب",href:"#reviews"},{label:"الخصوصية",href:"/privacy.html"},{label:"الشروط والأحكام",href:"/terms.html"}]';

js = js.replace(oldGv, newGv);

// 2. Update navItems in P5 for English mode
const oldNavItems = 'const navItems=isEn?[{label:"Features",href:"#features"},{label:"AI Tutor",href:"#ai-tutor"},{label:"Camera Solver",href:"#camera"},{label:"Reviews",href:"#reviews"}]:gv;';
const newNavItems = 'const navItems=isEn?[{label:"Features",href:"#features"},{label:"AI Tutor",href:"#ai-tutor"},{label:"Camera Solver",href:"#camera"},{label:"Reviews",href:"#reviews"},{label:"Privacy",href:"/privacy.html?lang=en"},{label:"Terms",href:"/terms.html?lang=en"}]:gv;';

js = js.replace(oldNavItems, newNavItems);

// 3. Update the language button styling to match "حمّل التطبيق" exactly
const oldLangBtn = 'x.jsx("button",{onClick:toggleTamLang,className:"flex items-center gap-1.5 px-3 py-1.5 rounded-xl border border-border bg-slate-50 hover:bg-slate-100 dark:bg-slate-800 dark:hover:bg-slate-700 text-xs font-bold text-foreground transition-all cursor-pointer shadow-2xs","aria-label":"Toggle Language",children:[x.jsx("span",{className:"text-sm leading-none",children:"🌐"}),x.jsx("span",{className:"leading-none font-bold",children:isEn?"AR":"EN"})]})';

const newLangBtn = 'x.jsx("button",{onClick:toggleTamLang,className:"flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-xl text-sm font-bold hover:bg-primary/90 transition-all shadow-sm cursor-pointer","aria-label":"Toggle Language",children:[x.jsx("span",{className:"text-base leading-none",children:"🌐"}),x.jsx("span",{className:"leading-none font-bold",children:isEn?"AR":"EN"})]})';

js = js.replace(oldLangBtn, newLangBtn);

// 4. Save to index-tam-v9.js
const v9Path = 'D:/My DOC/project/site/public/assets/index-tam-v9.js';
fs.writeFileSync(v9Path, js, 'utf8');
console.log('Saved index-tam-v9.js successfully!');

// 5. Update index.html to load index-tam-v9.js
const htmlPath = 'D:/My DOC/project/site/public/index.html';
const htmlContent = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1" />
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
    <meta http-equiv="Pragma" content="no-cache" />
    <meta http-equiv="Expires" content="0" />
    <title>تَم - منصة تعليمية ذكية</title>
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <script type="module" crossorigin src="/assets/index-tam-v9.js?v=9"></script>
    <link rel="stylesheet" crossorigin href="/assets/index-B6lj_HPu.css">
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
`;
fs.writeFileSync(htmlPath, htmlContent, 'utf8');
console.log('Updated index.html to load v9');
