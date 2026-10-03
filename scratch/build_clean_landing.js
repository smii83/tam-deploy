const fs = require('fs');

const jsPath = 'D:/My DOC/project/site/public/assets/index-tam-v4.js';
let js = fs.readFileSync(jsPath, 'utf8');

console.log('Original JS length:', js.length);

// 1. Remove lN from cN (Home page)
// In cN:
// children:[x.jsx(G5,{}),x.jsx("section",{id:"features",children:x.jsx(Z5,{})}),x.jsx("section",{id:"ai-tutor",children:x.jsx($5,{})}),x.jsx("section",{id:"camera",children:x.jsx(eN,{})}),x.jsx("section",{id:"reviews",children:x.jsx(iN,{})}),x.jsx(lN,{}),x.jsx("section",{id:"download",children:x.jsx(aN,{})})]
const oldHomeSections = 'x.jsx(iN,{}),x.jsx(lN,{}),x.jsx("section",{id:"download",children:x.jsx(aN,{})})';
const newHomeSections = 'x.jsx(iN,{}),x.jsx("section",{id:"download",children:x.jsx(aN,{})})';

if (js.includes(oldHomeSections)) {
  js = js.replace(oldHomeSections, newHomeSections);
  console.log('Successfully removed lN from cN!');
} else {
  console.log('Searching for lN occurrence in cN...');
  js = js.replace('x.jsx(lN,{})', 'null');
  console.log('Replaced x.jsx(lN,{}) with null');
}

// 2. Update gv (Navbar links)
// old: gv=[{label:"الميزات",href:"#features"},{label:"المدرس الذكي",href:"#ai-tutor"},{label:"حل بالكاميرا",href:"#camera"},{label:"الشروط والأحكام",href:"/terms.html"}]
const oldGv1 = '{label:"الشروط والأحكام",href:"/terms.html"}';
const oldGv2 = '{label:"الشروط والأحكام",href:"#terms"}';
const newGv = '{label:"آراء الطلاب",href:"#reviews"}';

if (js.includes(oldGv1)) {
  js = js.replace(oldGv1, newGv);
  console.log('Updated gv navigation links (removed terms, added reviews)');
} else if (js.includes(oldGv2)) {
  js = js.replace(oldGv2, newGv);
  console.log('Updated gv navigation links (removed #terms, added reviews)');
}

// 3. Remove all mentions of "كويت / كويتي / كويتية / سادس إلى 12"
// (a) Hero bullet 1
js = js.replace(
  'text:"منصة تَم تقدم دروساً كويتية وشروحات لجميع المواد والفصول"',
  'text:"منصة تَم تقدم شروحات وتجارب تعليمية تفاعلية لجميع المواد والمراحل"'
);

// (b) Hero bullet 3
js = js.replace(
  'text:"مدرس ذكي، حل بالكاميرا، واختبارات ذكية — من الصف السادس للثاني عشر"',
  'text:"مدرس ذكي، حل بالكاميرا، واختبارات تفاعلية — لكافة المراحل والمواد الدراسية"'
);

// (c) Features Y5 card 1
js = js.replace(
  'title:"شرح كويتي للمواد",description:"فيديوهات تعليمية مخصصة لكل مادة وفصل في المنهج الكويتي"',
  'title:"شروحات مرئية شاملة",description:"فيديوهات تعليمية وشروحات تفاعلية مخصصة لكل مادة وفصل دراسي"'
);

// (d) Features subtitle in Z5
js = js.replace(
  'children:"أدوات تعليمية مصمّمة خصيصاً لطالب الكويت"',
  'children:"أدوات تعليمية ذكية مصمّمة لمساعدتك على التفوق الدراسي"'
);

// (e) AI Tutor subtitle in $5
js = js.replace(
  'children:"مدرسك الخاص بشرح وحل ويجيب بالعربية على مدار الساعة. متوفر لجميع المواد والصفوف من الكويت."',
  'children:"مدرسك الخاص يشرح ويحل ويجيب على مدار الساعة لكافة المواد والمراحل الدراسية."'
);

// (f) Reem review in nN
js = js.replace(
  'text:"الملخصات والمراجعات مرتبة على حسب المنهج الكويتي بالضبط. كل شيء في مكانه وسهل الوصول له."',
  'text:"الملخصات والمراجعات مرتبة بدقة واحترافية وشاملة. كل شيء في مكانه وسهل الوصول له."'
);

// (g) Download CTA subtitle in aN
js = js.replace(
  'children:"انضم إلى آلاف الطلاب الكويتيين الذين يتعلمون بشكل أذكى"',
  'children:"انضم إلى آلاف الطلاب الذين يتعلمون بشكل أذكى وأسرع"'
);

// (h) Stats in aN
js = js.replace(
  '{value:"١٢ صف",label:"مغطى كامل"}',
  '{value:"شامل",label:"لكافة المواد والمراحل"}'
);

console.log('All text replacements completed.');

// Save updated JS to a new version file index-tam-v5.js
const v5Path = 'D:/My DOC/project/site/public/assets/index-tam-v5.js';
fs.writeFileSync(v5Path, js, 'utf8');
console.log('Saved index-tam-v5.js successfully.');
