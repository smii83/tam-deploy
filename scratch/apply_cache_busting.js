const fs = require('fs');
const path = require('path');

// 1. Read current JS bundle
const jsPath = 'D:/My DOC/project/site/public/assets/index-klBE3b22.js';
let jsContent = fs.readFileSync(jsPath, 'utf8');

// Ensure CodeCore in footer
const search1 = 'x.jsx("span",{children:"جميع الحقوق محفوظة لمنصة تَم"}),x.jsx("span",{children:"·"}),x.jsx("span",{children:"© ٢٠٢٦"}),x.jsx("span",{children:"·"}),x.jsx("a",{href:"#terms",className:"underline underline-offset-2 hover:opacity-80 transition-opacity",style:{color:"hsl(243,75%,72%)"},children:"شروط الخدمة والخصوصية"})';
const replace1 = 'x.jsx("span",{children:"جميع الحقوق محفوظة لـ CodeCore"}),x.jsx("span",{children:"·"}),x.jsx("span",{children:"© ٢٠٢٦"}),x.jsx("span",{children:"·"}),x.jsx("a",{href:"/privacy.html",className:"underline underline-offset-2 hover:opacity-80 transition-opacity",style:{color:"hsl(243,75%,72%)"},children:"سياسة الخصوصية"}),x.jsx("span",{children:"·"}),x.jsx("a",{href:"/terms.html",className:"underline underline-offset-2 hover:opacity-80 transition-opacity",style:{color:"hsl(243,75%,72%)"},children:"شروط الاستخدام"})';

if (jsContent.includes(search1)) {
  jsContent = jsContent.replace(search1, replace1);
  console.log('Replaced footer target 1');
}

const search2 = 'children:"جميع الحقوق محفوظة لمنصة تَم · © ٢٠٢٦"';
const replace2 = 'children:"جميع الحقوق محفوظة لـ CodeCore · © ٢٠٢٦"';
if (jsContent.includes(search2)) {
  jsContent = jsContent.replace(search2, replace2);
  console.log('Replaced terms route target 2');
}

// Also update navbar if desired: {label:"الشروط والأحكام",href:"#terms"} -> {label:"الشروط والأحكام",href:"/terms.html"}
const searchNav = '{label:"الشروط والأحكام",href:"#terms"}';
const replaceNav = '{label:"الشروط والأحكام",href:"/terms.html"}';
if (jsContent.includes(searchNav)) {
  jsContent = jsContent.replace(searchNav, replaceNav);
  console.log('Replaced navbar terms link to /terms.html');
}

// Write to new file with new hash to bypass ANY browser cache
const newJsPath = 'D:/My DOC/project/site/public/assets/index-tam-v3.js';
fs.writeFileSync(newJsPath, jsContent, 'utf8');
fs.writeFileSync(jsPath, jsContent, 'utf8');
console.log('Saved new JS file:', newJsPath);

// 2. Update index.html
const htmlPath = 'D:/My DOC/project/site/public/index.html';
const htmlContent = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1" />
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
    <meta http-equiv="Pragma" content="no-cache" />
    <meta http-equiv="Expires" content="0" />
    <title>تَم - منصة تعليمية كويتية</title>
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <script type="module" crossorigin src="/assets/index-tam-v3.js?v=3"></script>
    <link rel="stylesheet" crossorigin href="/assets/index-B6lj_HPu.css">
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
`;
fs.writeFileSync(htmlPath, htmlContent, 'utf8');
console.log('Updated index.html with new script src and cache headers');

// 3. Update firebase.json
const fbConfig = {
  hosting: {
    site: "website-tam-4a01b",
    public: "public",
    cleanUrls: false,
    trailingSlash: false,
    headers: [
      {
        source: "**/*.@(html|js|css)",
        headers: [
          { "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" }
        ]
      },
      {
        source: "/",
        headers: [
          { "key": "Cache-Control", "value": "no-cache, no-store, must-revalidate" }
        ]
      }
    ],
    rewrites: [
      {
        source: "/privacy",
        destination: "/privacy.html"
      },
      {
        source: "/terms",
        destination: "/terms.html"
      }
    ],
    ignore: [
      "firebase.json",
      "**/.*",
      "**/node_modules/**"
    ]
  }
};
fs.writeFileSync('D:/My DOC/project/site/firebase.json', JSON.stringify(fbConfig, null, 2), 'utf8');
console.log('Updated firebase.json with Cache-Control headers');
