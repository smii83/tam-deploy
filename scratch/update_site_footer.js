const fs = require('fs');
const path = 'D:/My DOC/project/site/public/assets/index-klBE3b22.js';

let content = fs.readFileSync(path, 'utf8');

// Target 1 - Main footer
const search1 = 'x.jsx("span",{children:"جميع الحقوق محفوظة لمنصة تَم"}),x.jsx("span",{children:"·"}),x.jsx("span",{children:"© ٢٠٢٦"}),x.jsx("span",{children:"·"}),x.jsx("a",{href:"#terms",className:"underline underline-offset-2 hover:opacity-80 transition-opacity",style:{color:"hsl(243,75%,72%)"},children:"شروط الخدمة والخصوصية"})';

const replace1 = 'x.jsx("span",{children:"جميع الحقوق محفوظة لـ CodeCore"}),x.jsx("span",{children:"·"}),x.jsx("span",{children:"© ٢٠٢٦"}),x.jsx("span",{children:"·"}),x.jsx("a",{href:"/privacy.html",className:"underline underline-offset-2 hover:opacity-80 transition-opacity",style:{color:"hsl(243,75%,72%)"},children:"سياسة الخصوصية"}),x.jsx("span",{children:"·"}),x.jsx("a",{href:"/terms.html",className:"underline underline-offset-2 hover:opacity-80 transition-opacity",style:{color:"hsl(243,75%,72%)"},children:"شروط الاستخدام"})';

console.log('Search 1 in content:', content.includes(search1));

if (content.includes(search1)) {
  content = content.replace(search1, replace1);
  console.log('Replaced target 1 successfully!');
} else {
  console.error('Target 1 NOT found!');
}

// Target 2 - Terms route footer
const search2 = 'children:"جميع الحقوق محفوظة لمنصة تَم · © ٢٠٢٦"';
const replace2 = 'children:"جميع الحقوق محفوظة لـ CodeCore · © ٢٠٢٦"';

console.log('Search 2 in content:', content.includes(search2));

if (content.includes(search2)) {
  content = content.replace(search2, replace2);
  console.log('Replaced target 2 successfully!');
} else {
  console.error('Target 2 NOT found!');
}

fs.writeFileSync(path, content, 'utf8');
console.log('File written successfully.');
