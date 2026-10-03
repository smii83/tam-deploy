const fs = require('fs');

const v9Path = 'D:/My DOC/project/site/public/assets/index-tam-v9.js';
let js = fs.readFileSync(v9Path, 'utf8');

const oldLangBtn = 'x.jsx("button",{onClick:toggleTamLang,className:"flex items-center gap-2 bg-primary text-primary-foreground px-4 py-2 rounded-xl text-sm font-bold hover:bg-primary/90 transition-all shadow-sm cursor-pointer","aria-label":"Toggle Language",children:[x.jsx("span",{className:"text-base leading-none",children:"🌐"}),x.jsx("span",{className:"leading-none font-bold",children:isEn?"AR":"EN"})]})';

const newLangBtn = 'x.jsx("button",{onClick:toggleTamLang,className:"flex items-center justify-center bg-primary text-primary-foreground px-4 py-2 rounded-xl text-sm font-bold hover:bg-primary/90 transition-all shadow-sm cursor-pointer","aria-label":"Toggle Language",children:x.jsx("span",{className:"leading-none font-bold",children:isEn?"AR":"EN"})})';

if (!js.includes(oldLangBtn)) {
  console.error('ERROR: oldLangBtn not found in index-tam-v9.js!');
  process.exit(1);
}

js = js.replace(oldLangBtn, newLangBtn);

// Save to index-tam-v10.js
const v10Path = 'D:/My DOC/project/site/public/assets/index-tam-v10.js';
fs.writeFileSync(v10Path, js, 'utf8');
console.log('Successfully written index-tam-v10.js');

// Update index.html
const htmlPath = 'D:/My DOC/project/site/public/index.html';
let html = fs.readFileSync(htmlPath, 'utf8');
html = html.replace('index-tam-v9.js?v=9', 'index-tam-v10.js?v=10');
fs.writeFileSync(htmlPath, html, 'utf8');
console.log('Successfully updated index.html to v10');
