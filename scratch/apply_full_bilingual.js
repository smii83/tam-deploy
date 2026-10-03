const fs = require('fs');

const jsPath = 'D:/My DOC/project/site/public/assets/index-tam-v6.js';
let js = fs.readFileSync(jsPath, 'utf8');

// 1. Update G5 (Hero)
const oldG5 = 'function G5(){return x.jsxs("section"';
const newG5 = 'function G5(){const lang=useTamLang();const isEn=lang==="en";return x.jsxs("section"';
js = js.replace(oldG5, newG5);

// G5 Badge
js = js.replace('children:"منصة تَم التعليمية"', 'children:isEn?"TAM Educational Platform":"منصة تَم التعليمية"');

// G5 Title
js = js.replace('children:"تعلم بذكاء"', 'children:isEn?"Learn Smarter":"تعلم بذكاء"');
js = js.replace('children:"مع منصة"', 'children:isEn?"with TAM":"مع منصة"');

// G5 Hero Bullets
const oldBullets = '[{color:"hsl(243,75%,55%)",text:"منصة تَم تقدم شروحات وتجارب تعليمية تفاعلية لجميع المواد والمراحل"},{color:"hsl(199,80%,44%)",text:\'ملخصات "الزبدة" الشاملة لكل فصل جاهزة للتحميل\'},{color:"hsl(268,65%,58%)",text:"مدرس ذكي، حل بالكاميرا، واختبارات تفاعلية — لكافة المراحل والمواد الدراسية"}]';
const newBullets = '[{color:"hsl(243,75%,55%)",text:isEn?"Interactive video lessons and study tools for all subjects & grades":"منصة تَم تقدم شروحات وتجارب تعليمية تفاعلية لجميع المواد والمراحل"},{color:"hsl(199,80%,44%)",text:isEn?"Comprehensive study summaries ready to download for revision and exams":\'ملخصات "الزبدة" الشاملة لكل فصل جاهزة للتحميل\'},{color:"hsl(268,65%,58%)",text:isEn?"Smart AI Tutor, Camera Solver, and interactive quizzes for all grades":"مدرس ذكي، حل بالكاميرا، واختبارات تفاعلية — لكافة المراحل والمواد الدراسية"}]';
js = js.replace(oldBullets, newBullets);

// G5 Buttons
js = js.replace('children:[x.jsx(Vf,{size:18}),"ابدأ الآن مجاناً"]', 'children:[x.jsx(Vf,{size:18}),isEn?"Get Started Free":"ابدأ الآن مجاناً"]');
js = js.replace('children:"اكتشف الميزات"', 'children:isEn?"Explore Features":"اكتشف الميزات"');

// G5 Floating badges
js = js.replace('children:"+٥٠"', 'children:isEn?"+50":"+٥٠"');
js = js.replace('children:"نقاط XP مكتسبة"', 'children:isEn?"XP Points Earned":"نقاط XP مكتسبة"');
js = js.replace('children:"تم الحل بنجاح ✓"', 'children:isEn?"Solved Successfully ✓":"تم الحل بنجاح ✓"');


// 2. Update Z5 (Features)
const oldZ5 = 'function Z5(){return x.jsxs("section",{id:"features",className:"relative py-24 bg-white overflow-hidden",dir:"rtl"';
const newZ5 = 'function Z5(){const lang=useTamLang();const isEn=lang==="en";return x.jsxs("section",{id:"features",className:"relative py-24 bg-white overflow-hidden",dir:isEn?"ltr":"rtl"';
js = js.replace(oldZ5, newZ5);

js = js.replace('children:"كل ما تحتاجه"', 'children:isEn?"Everything You Need":"كل ما تحتاجه"');
js = js.replace('children:["في مكان"," ",x.jsx("span",{className:"text-transparent bg-clip-text",style:{backgroundImage:"linear-gradient(100deg, hsl(243,75%,55%), hsl(268,65%,60%))"},children:"واحد"})]', 'children:[isEn?"All in One ":"في مكان "," ",x.jsx("span",{className:"text-transparent bg-clip-text",style:{backgroundImage:"linear-gradient(100deg, hsl(243,75%,55%), hsl(268,65%,60%))"},children:isEn?"Platform":"واحد"})]');
js = js.replace('children:"أدوات تعليمية ذكية مصمّمة لمساعدتك على التفوق الدراسي"', 'children:isEn?"Smart educational tools designed to help you excel academically":"أدوات تعليمية ذكية مصمّمة لمساعدتك على التفوق الدراسي"');

// Features Cards array Y5:
const oldY5 = `const Y5=[{icon:oE,title:"شروحات مرئية شاملة",description:"فيديوهات تعليمية وشروحات تفاعلية مخصصة لكل مادة وفصل دراسي",iconColor:"#4F46E5",iconBg:"hsl(243,75%,55%,0.10)",borderColor:"hsl(243,75%,55%,0.15)",glowColor:"hsl(243,75%,55%,0.12)",badge:null},{icon:WA,title:'ملخصات "الزبدة"',description:"ملخصات PDF شاملة لكل الفصول الدراسية جاهزة للتحميل والمراجعة",iconColor:"#4F46E5",iconBg:"hsl(243,75%,55%,0.10)",borderColor:"hsl(243,75%,55%,0.15)",glowColor:"hsl(243,75%,55%,0.12)",badge:null},{icon:zf,title:"المدرس الذكي",description:"مدرس بالذكاء الاصطناعي يشرح ويحل ويجيب على أسئلتك على مدار الساعة",iconColor:"#0EA5E9",iconBg:"hsl(199,80%,48%,0.10)",borderColor:"hsl(199,80%,48%,0.15)",glowColor:"hsl(199,80%,48%,0.12)",badge:null},{icon:dx,title:"حل بالكاميرا",description:"صوّر السؤال والذكاء الاصطناعي يحله فوراً خطوة بخطوة بالتفصيل",iconColor:"#9333EA",iconBg:"hsl(268,65%,58%,0.10)",borderColor:"hsl(268,65%,58%,0.15)",glowColor:"hsl(268,65%,58%,0.12)",badge:"AI"},{icon:uE,title:"اختبارات ذكية",description:"اختبارات مولّدة بالذكاء الاصطناعي وأسئلة تدريبية متنوعة لكل اختبار",iconColor:"#0EA5E9",iconBg:"hsl(199,80%,48%,0.10)",borderColor:"hsl(199,80%,48%,0.15)",glowColor:"hsl(199,80%,48%,0.12)",badge:"جديد"},{icon:JA,title:"نقاط XP والإنجازات",description:"نظام مكافآت يومي يحفزك على الاستمرار وتحقيق الإنجازات",iconColor:"#4F46E5",iconBg:"hsl(243,75%,55%,0.10)",borderColor:"hsl(243,75%,55%,0.15)",glowColor:"hsl(243,75%,55%,0.12)",badge:null}]`;

const newY5 = `const Y5=[{icon:oE,titleAr:"شروحات مرئية شاملة",titleEn:"Visual Video Lessons",descAr:"فيديوهات تعليمية وشروحات تفاعلية مخصصة لكل مادة وفصل دراسي",descEn:"Educational videos and interactive explanations for all subjects & terms",iconColor:"#4F46E5",iconBg:"hsl(243,75%,55%,0.10)",borderColor:"hsl(243,75%,55%,0.15)",glowColor:"hsl(243,75%,55%,0.12)",badge:null},{icon:WA,titleAr:'ملخصات "الزبدة"',titleEn:"Study Summaries",descAr:"ملخصات PDF شاملة لكل الفصول الدراسية جاهزة للتحميل والمراجعة",descEn:"Comprehensive PDF summaries ready to download for revision and exams",iconColor:"#4F46E5",iconBg:"hsl(243,75%,55%,0.10)",borderColor:"hsl(243,75%,55%,0.15)",glowColor:"hsl(243,75%,55%,0.12)",badge:null},{icon:zf,titleAr:"المدرس الذكي",titleEn:"Smart AI Tutor",descAr:"مدرس بالذكاء الاصطناعي يشرح ويحل ويجيب على أسئلتك على مدار الساعة",descEn:"AI tutor that explains, solves, and answers your questions 24/7",iconColor:"#0EA5E9",iconBg:"hsl(199,80%,48%,0.10)",borderColor:"hsl(199,80%,48%,0.15)",glowColor:"hsl(199,80%,48%,0.12)",badge:null},{icon:dx,titleAr:"حل بالكاميرا",titleEn:"Camera Solver",descAr:"صوّر السؤال والذكاء الاصطناعي يحله فوراً خطوة بخطوة بالتفصيل",descEn:"Snap a photo of the question and AI solves it step-by-step instantly",iconColor:"#9333EA",iconBg:"hsl(268,65%,58%,0.10)",borderColor:"hsl(268,65%,58%,0.15)",glowColor:"hsl(268,65%,58%,0.12)",badge:"AI"},{icon:uE,titleAr:"اختبارات ذكية",titleEn:"Smart Quizzes",descAr:"اختبارات مولّدة بالذكاء الاصطناعي وأسئلة تدريبية متنوعة لكل اختبار",descEn:"AI-generated practice quizzes and questions tailored for every exam",iconColor:"#0EA5E9",iconBg:"hsl(199,80%,48%,0.10)",borderColor:"hsl(199,80%,48%,0.15)",glowColor:"hsl(199,80%,48%,0.12)",badgeAr:"جديد",badgeEn:"NEW"},{icon:JA,titleAr:"نقاط XP والإنجازات",titleEn:"XP Points & Streaks",descAr:"نظام مكافآت يومي يحفزك على الاستمرار وتحقيق الإنجازات",descEn:"Daily reward system that motivates you to build consistent study habits",iconColor:"#4F46E5",iconBg:"hsl(243,75%,55%,0.10)",borderColor:"hsl(243,75%,55%,0.15)",glowColor:"hsl(243,75%,55%,0.12)",badge:null}]`;

js = js.replace(oldY5, newY5);

// Update card rendering in Z5:
js = js.replace('children:e.title', 'children:isEn?e.titleEn:e.titleAr');
js = js.replace('children:e.description', 'children:isEn?e.descEn:e.descAr');
js = js.replace('children:e.badge', 'children:e.badge?(isEn?(e.badgeEn||e.badge):(e.badgeAr||e.badge)):null');


// 3. Update $5 (AI Tutor)
const oldTutor = 'function $5(){return x.jsxs("section"';
const newTutor = 'function $5(){const lang=useTamLang();const isEn=lang==="en";return x.jsxs("section"';
js = js.replace(oldTutor, newTutor);

js = js.replace('children:"الذكاء الاصطناعي"', 'children:isEn?"Artificial Intelligence":"الذكاء الاصطناعي"');
js = js.replace('children:["اسأل ",x.jsx("span",{className:"text-transparent bg-clip-text bg-gradient-to-r from-primary to-pink-300",children:"أي سؤال"})]', 'children:[isEn?"Ask ":"اسأل ",x.jsx("span",{className:"text-transparent bg-clip-text bg-gradient-to-r from-primary to-pink-300",children:isEn?"Any Question":"أي سؤال"})]');
js = js.replace('children:"مدرسك الخاص يشرح ويحل ويجيب على مدار الساعة لكافة المواد والمراحل الدراسية."', 'children:isEn?"Your personal 24/7 AI tutor explains, solves, and guides you across all subjects and grades.":"مدرسك الخاص يشرح ويحل ويجيب على مدار الساعة لكافة المواد والمراحل الدراسية."');

// Bullets in AI tutor:
js = js.replace('children:"شرح مفصّل لكل مادة بالعربية"', 'children:isEn?"Detailed step-by-step explanations":"شرح مفصّل لكل مادة بالعربية"');
js = js.replace('children:"حلول خطوة بخطوة للمسائل الصعبة"', 'children:isEn?"Step-by-step solutions to challenging problems":"حلول خطوة بخطوة للمسائل الصعبة"');
js = js.replace('children:"متاح 24/7 بدون انقطاع"', 'children:isEn?"Available 24/7 anytime, anywhere":"متاح 24/7 بدون انقطاع"');


// 4. Update eN (Camera)
const oldCam = 'function eN(){return x.jsxs("section"';
const newCam = 'function eN(){const lang=useTamLang();const isEn=lang==="en";return x.jsxs("section"';
js = js.replace(oldCam, newCam);

js = js.replace('children:[x.jsx("span",{className:"w-2 h-2 rounded-full bg-accent animate-pulse"}),"ميزة جديدة"]', 'children:[x.jsx("span",{className:"w-2 h-2 rounded-full bg-accent animate-pulse"}),isEn?"New Feature":"ميزة جديدة"]');
js = js.replace('children:["صوّر وحلّ"," ",x.jsx("span",{className:"text-transparent bg-clip-text bg-gradient-to-r from-accent to-yellow-300",children:"فوراً"})]', 'children:[isEn?"Snap & Solve ":"صوّر وحلّ "," ",x.jsx("span",{className:"text-transparent bg-clip-text bg-gradient-to-r from-accent to-yellow-300",children:isEn?"Instantly":"فوراً"})]');
js = js.replace('children:"وجّه الكاميرا نحو أي سؤال أو مسألة والذكاء الاصطناعي يحلها خطوة بخطوة"', 'children:isEn?"Point your camera at any question or equation, and AI solves it step by step with clear explanations.":"وجّه الكاميرا نحو أي سؤال أو مسألة والذكاء الاصطناعي يحلها خطوة بخطوة"');


// 5. Update iN (Reviews)
const oldReviews = 'function iN(){return x.jsxs("section"';
const newReviews = 'function iN(){const lang=useTamLang();const isEn=lang==="en";return x.jsxs("section"';
js = js.replace(oldReviews, newReviews);

js = js.replace('children:"آراء الطلاب"', 'children:isEn?"Student Reviews":"آراء الطلاب"');
js = js.replace('children:["ماذا يقول"," ",x.jsx("span",{className:"text-transparent bg-clip-text bg-gradient-to-r from-primary to-accent",children:"طلابنا"})]', 'children:[isEn?"What Our ":"ماذا يقول "," ",x.jsx("span",{className:"text-transparent bg-clip-text bg-gradient-to-r from-primary to-accent",children:isEn?"Students Say":"طلابنا"})]');
js = js.replace('children:"على App Store و Google Play"', 'children:isEn?"on App Store & Google Play":"على App Store و Google Play"');


// 6. Update aN (Download CTA & Footer)
const oldDownload = 'function aN(){return x.jsxs("section"';
const newDownload = 'function aN(){const lang=useTamLang();const isEn=lang==="en";return x.jsxs("section"';
js = js.replace(oldDownload, newDownload);

js = js.replace('children:"ابدأ مجاناً اليوم"', 'children:isEn?"Start Free Today":"ابدأ مجاناً اليوم"');
js = js.replace('children:"جاهز لتغيير طريقة دراستك؟"', 'children:isEn?"Ready to Transform Your Learning?":"جاهز لتغيير طريقة دراستك؟"');
js = js.replace('children:"انضم إلى آلاف الطلاب الذين يتعلمون بشكل أذكى وأسرع"', 'children:isEn?"Join thousands of students learning smarter and faster with TAM.":"انضم إلى آلاف الطلاب الذين يتعلمون بشكل أذكى وأسرع"');

// Stats in aN
js = js.replace('{value:"٢٤/٧",label:"متاح دائماً"}', '{value:isEn?"24/7":"٢٤/٧",label:isEn?"Always Available":"متاح دائماً"}');
js = js.replace('{value:"شامل",label:"لكافة المواد والمراحل"}', '{value:isEn?"Complete":"شامل",label:isEn?"All Subjects & Grades":"لكافة المواد والمراحل"}');

// Store buttons in aN:
js = js.replace('children:"تحميل من"', 'children:isEn?"Download on":"تحميل من"');

// Footer links and copyright in aN:
const oldFooterText = 'x.jsx("span",{children:"جميع الحقوق محفوظة لـ CodeCore"}),x.jsx("span",{children:"·"}),x.jsx("span",{children:"© ٢٠٢٦"}),x.jsx("span",{children:"·"}),x.jsx("a",{href:"/privacy.html",className:"underline underline-offset-2 hover:opacity-80 transition-opacity",style:{color:"hsl(243,75%,72%)"},children:"سياسة الخصوصية"}),x.jsx("span",{children:"·"}),x.jsx("a",{href:"/terms.html",className:"underline underline-offset-2 hover:opacity-80 transition-opacity",style:{color:"hsl(243,75%,72%)"},children:"شروط الاستخدام"})';

const newFooterText = 'x.jsx("span",{children:isEn?"© 2026 CodeCore. All rights reserved.":"جميع الحقوق محفوظة لـ CodeCore"}),x.jsx("span",{children:"·"}),x.jsx("span",{children:isEn?"":"© ٢٠٢٦"}),x.jsx("span",{children:isEn?"":"·"}),x.jsx("a",{href:isEn?"/privacy.html?lang=en":"/privacy.html",className:"underline underline-offset-2 hover:opacity-80 transition-opacity",style:{color:"hsl(243,75%,72%)"},children:isEn?"Privacy Policy":"سياسة الخصوصية"}),x.jsx("span",{children:"·"}),x.jsx("a",{href:isEn?"/terms.html?lang=en":"/terms.html",className:"underline underline-offset-2 hover:opacity-80 transition-opacity",style:{color:"hsl(243,75%,72%)"},children:isEn?"Terms of Use":"شروط الاستخدام"})';

js = js.replace(oldFooterText, newFooterText);

// Write to final bundle index-tam-v7.js
const finalJsPath = 'D:/My DOC/project/site/public/assets/index-tam-v7.js';
fs.writeFileSync(finalJsPath, js, 'utf8');
console.log('Saved final bilingual JS bundle index-tam-v7.js successfully!');
