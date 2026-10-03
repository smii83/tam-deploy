const fs = require('fs');

const jsPath = 'D:/My DOC/project/site/public/assets/index-tam-v7.js';
let js = fs.readFileSync(jsPath, 'utf8');

// 1. Replace the em-dash "—" with ".." (نقطتين) in hero bullet
js = js.replace(
  'مدرس ذكي، حل بالكاميرا، واختبارات تفاعلية — لكافة المراحل والمواد الدراسية',
  'مدرس ذكي، حل بالكاميرا، واختبارات تفاعلية .. لكافة المراحل والمواد الدراسية'
);

js = js.replace(
  'مدرس ذكي، حل بالكاميرا، واختبارات تفاعلية - لكافة المراحل والمواد الدراسية',
  'مدرس ذكي، حل بالكاميرا، واختبارات تفاعلية .. لكافة المراحل والمواد الدراسية'
);

// 2. Define Y5 with all properties (title, titleAr, titleEn, description, descAr, descEn, badge, badgeAr, badgeEn)
const oldY5 = js.substring(js.indexOf('const Y5='), js.indexOf(',X5={hidden:{},'));

const newY5 = `const Y5=[{icon:oE,title:"شروحات مرئية شاملة",titleAr:"شروحات مرئية شاملة",titleEn:"Visual Video Lessons",description:"فيديوهات تعليمية وشروحات تفاعلية مخصصة لكل مادة وفصل دراسي",descAr:"فيديوهات تعليمية وشروحات تفاعلية مخصصة لكل مادة وفصل دراسي",descEn:"Educational videos and interactive explanations for all subjects & terms",iconColor:"#4F46E5",iconBg:"hsl(243,75%,55%,0.10)",borderColor:"hsl(243,75%,55%,0.15)",glowColor:"hsl(243,75%,55%,0.12)",badge:null},{icon:WA,title:'ملخصات "الزبدة"',titleAr:'ملخصات "الزبدة"',titleEn:"Study Summaries",description:"ملخصات PDF شاملة لكل الفصول الدراسية جاهزة للتحميل والمراجعة قبل الامتحانات",descAr:"ملخصات PDF شاملة لكل الفصول الدراسية جاهزة للتحميل والمراجعة قبل الامتحانات",descEn:"Comprehensive PDF summaries ready to download for revision and exams",iconColor:"#0EA5E9",iconBg:"hsl(199,80%,48%,0.10)",borderColor:"hsl(199,80%,48%,0.15)",glowColor:"hsl(199,80%,48%,0.12)",badge:null},{icon:zf,title:"المدرس الذكي",titleAr:"المدرس الذكي",titleEn:"Smart AI Tutor",description:"مدرس بالذكاء الاصطناعي يشرح ويحل ويجيب على أسئلتك بالعربية على مدار الساعة",descAr:"مدرس بالذكاء الاصطناعي يشرح ويحل ويجيب على أسئلتك بالعربية على مدار الساعة",descEn:"AI tutor that explains, solves, and answers your questions 24/7",iconColor:"#8B5CF6",iconBg:"hsl(268,65%,58%,0.10)",borderColor:"hsl(268,65%,58%,0.15)",glowColor:"hsl(268,65%,58%,0.12)",badge:"AI"},{icon:dx,title:"حل بالكاميرا",titleAr:"حل بالكاميرا",titleEn:"Camera Solver",description:"صوّر السؤال والذكاء الاصطناعي يحله فوراً خطوة بخطوة بالتفصيل",descAr:"صوّر السؤال والذكاء الاصطناعي يحله فوراً خطوة بخطوة بالتفصيل",descEn:"Snap a photo of the question and AI solves it step-by-step instantly",iconColor:"#0EA5E9",iconBg:"hsl(199,80%,48%,0.10)",borderColor:"hsl(199,80%,48%,0.15)",glowColor:"hsl(199,80%,48%,0.12)",badge:"جديد",badgeAr:"جديد",badgeEn:"NEW"},{icon:uE,title:"اختبارات ذكية",titleAr:"اختبارات ذكية",titleEn:"Smart Quizzes",description:"اختبارات مولّدة بالذكاء الاصطناعي وأسئلة تدريبية متنوعة لكل المواد",descAr:"اختبارات مولّدة بالذكاء الاصطناعي وأسئلة تدريبية متنوعة لكل المواد",descEn:"AI-generated practice quizzes and questions tailored for every exam",iconColor:"#4F46E5",iconBg:"hsl(243,75%,55%,0.10)",borderColor:"hsl(243,75%,55%,0.15)",glowColor:"hsl(243,75%,55%,0.12)",badge:null},{icon:JA,title:"نقاط XP والإنجازات",titleAr:"نقاط XP والإنجازات",titleEn:"XP Points & Streaks",description:"نظام مكافآت يومي يحفزك على الاستمرار وتحقيق الإنجازات",descAr:"نظام مكافآت يومي يحفزك على الاستمرار وتحقيق الإنجازات",descEn:"Daily reward system that motivates you to build consistent study habits",iconColor:"#8B5CF6",iconBg:"hsl(268,65%,58%,0.10)",borderColor:"hsl(268,65%,58%,0.15)",glowColor:"hsl(268,65%,58%,0.12)",badge:null}]`;

js = js.replace(oldY5, newY5);

// Make sure children rendering uses fallback
js = js.replace('children:isEn?e.titleEn:e.titleAr', 'children:isEn?(e.titleEn||e.title):(e.titleAr||e.title)');
js = js.replace('children:isEn?e.descEn:e.descAr', 'children:isEn?(e.descEn||e.description):(e.descAr||e.description)');

// Write to index-tam-v8.js
const v8Path = 'D:/My DOC/project/site/public/assets/index-tam-v8.js';
fs.writeFileSync(v8Path, js, 'utf8');
console.log('Saved index-tam-v8.js with restored features cards and two dots in hero!');

// Update index.html to load index-tam-v8.js
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
    <script type="module" crossorigin src="/assets/index-tam-v8.js?v=8"></script>
    <link rel="stylesheet" crossorigin href="/assets/index-B6lj_HPu.css">
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
`;
fs.writeFileSync(htmlPath, htmlContent, 'utf8');
console.log('Updated index.html to load v8');
