const fs = require('fs');
const path = require('path');

const sitePublic = 'D:/My DOC/project/site/public';
const localAdmin = 'c:/Users/smiip/OneDrive/Desktop/TAM/admin_dashboard';

// 1. Update terms.html in site
console.log('--- Updating terms.html in site ---');
let terms = fs.readFileSync(path.join(sitePublic, 'terms.html'), 'utf8');

// Replace emails
terms = terms.replace(/support\.codecore@gmail\.com/g, 'support@codecore.llc');

// Replace activation text with instagram
terms = terms.replace(
  '<div data-ar="<strong>في حال وجود مشكلة في التفعيل:</strong> تواصل معنا عبر البريد الإلكتروني (support@codecore.llc) أو إنستغرام مع إرفاق إثبات الدفع وسنحل مشكلتك خلال 24 ساعة." data-en="<strong>In case of activation issues:</strong> Contact us via email (support@codecore.llc) or Instagram with proof of payment and we\'ll resolve it within 24 hours."><strong>في حال وجود مشكلة في التفعيل:</strong> تواصل معنا عبر البريد الإلكتروني (support@codecore.llc) أو إنستغرام مع إرفاق إثبات الدفع وسنحل مشكلتك خلال 24 ساعة.</div>',
  '<div data-ar="<strong>في حال وجود مشكلة في التفعيل:</strong> تواصل معنا عبر البريد الإلكتروني (support@codecore.llc) مع إرفاق إثبات الدفع وسنحل مشكلتك خلال 24 ساعة." data-en="<strong>In case of activation issues:</strong> Contact us via email (support@codecore.llc) with proof of payment and we\'ll resolve it within 24 hours."><strong>في حال وجود مشكلة في التفعيل:</strong> تواصل معنا عبر البريد الإلكتروني (support@codecore.llc) مع إرفاق إثبات الدفع وسنحل مشكلتك خلال 24 ساعة.</div>'
);
// Also handle case if old email was still in data-ar
terms = terms.replace(
  /تواصل معنا عبر البريد الإلكتروني \([^)]+\) أو إنستغرام مع إرفاق إثبات الدفع/g,
  'تواصل معنا عبر البريد الإلكتروني (support@codecore.llc) مع إرفاق إثبات الدفع'
);
terms = terms.replace(
  /Contact us via email \([^)]+\) or Instagram with proof of payment/g,
  'Contact us via email (support@codecore.llc) with proof of payment'
);

// Remove Instagram contact item from terms.html
const oldInstaTermsItem = `<div class="contact-item">
            <span>📸</span>
            <a href="https://instagram.com/tam.learn" target="_blank">@tam.learn</a>
            <span class="contact-label" data-ar="على إنستغرام" data-en="on Instagram">على إنستغرام</span>
          </div>`;

terms = terms.replace(oldInstaTermsItem, '');
// Also regex remove if whitespace differs
terms = terms.replace(/<div class="contact-item">\s*<span>📸<\/span>\s*<a href="https:\/\/instagram\.com\/tam\.learn"[^>]*>@tam\.learn<\/a>\s*<span class="contact-label"[^>]*>.*?<\/span>\s*<\/div>/s, '');

fs.writeFileSync(path.join(sitePublic, 'terms.html'), terms, 'utf8');
console.log('terms.html updated.');


// 2. Update privacy.html in site
console.log('--- Updating privacy.html in site ---');
let privacy = fs.readFileSync(path.join(sitePublic, 'privacy.html'), 'utf8');

// Replace emails
privacy = privacy.replace(/support\.codecore@gmail\.com/g, 'support@codecore.llc');

// Remove Instagram contact item from privacy.html
privacy = privacy.replace(oldInstaTermsItem, '');
privacy = privacy.replace(/<div class="contact-item">\s*<span>📸<\/span>\s*<a href="https:\/\/instagram\.com\/tam\.learn"[^>]*>@tam\.learn<\/a>\s*<span class="contact-label"[^>]*>.*?<\/span>\s*<\/div>/s, '');

fs.writeFileSync(path.join(sitePublic, 'privacy.html'), privacy, 'utf8');
console.log('privacy.html updated.');


// 3. Update Landing Page JS Bundle (index-tam-v11.js)
console.log('--- Creating index-tam-v11.js ---');
const v10Path = path.join(sitePublic, 'assets/index-tam-v10.js');
let js = fs.readFileSync(v10Path, 'utf8');

// The Instagram button in v10:
const oldInstaButton = 'x.jsx(pt.div,{variants:Vs,children:x.jsxs(pt.a,{href:"https://www.instagram.com/tam.learn",target:"_blank",rel:"noopener noreferrer",whileHover:{scale:1.04},whileTap:{scale:.97},transition:{type:"spring",stiffness:300,damping:18},className:"inline-flex items-center gap-3 px-6 py-3 rounded-2xl font-bold text-sm transition-colors",style:{border:"1px solid hsl(0,0%,100%,0.12)",background:"hsl(0,0%,100%,0.05)",color:"hsl(0,0%,85%)"},children:[x.jsx(eE,{size:18,className:"text-pink-400"}),x.jsx("span",{children:"تابعنا على الانستغرام"}),x.jsx("span",{className:"text-pink-400 font-black",children:"@tam.learn"})]})})';

// New Email button with mail icon:
const newEmailButton = 'x.jsx(pt.div,{variants:Vs,children:x.jsxs(pt.a,{href:"mailto:support@codecore.llc",whileHover:{scale:1.04},whileTap:{scale:.97},transition:{type:"spring",stiffness:300,damping:18},className:"inline-flex items-center gap-3 px-6 py-3 rounded-2xl font-bold text-sm transition-colors",style:{border:"1px solid hsl(0,0%,100%,0.12)",background:"hsl(0,0%,100%,0.05)",color:"hsl(0,0%,85%)"},children:[x.jsxs("svg",{width:18,height:18,viewBox:"0 0 24 24",fill:"none",stroke:"currentColor",strokeWidth:2,strokeLinecap:"round",strokeLinejoin:"round",className:"text-indigo-400",children:[x.jsx("rect",{width:"20",height:"16",x:"2",y:"4",rx:"2"}),x.jsx("path",{d:"m22 7-8.97 5.7a1.94 1.94 0 0 1-2.06 0L2 7"})]}),x.jsx("span",{children:isEn?"Email Support:":"البريد الإلكتروني للتواصل:"}),x.jsx("span",{className:"text-indigo-400 font-black",children:"support@codecore.llc"})]})})';

if (!js.includes(oldInstaButton)) {
  console.error('ERROR: oldInstaButton pattern not found in v10!');
} else {
  js = js.replace(oldInstaButton, newEmailButton);
  console.log('Replaced Instagram button with Email button successfully.');
}

const v11Path = path.join(sitePublic, 'assets/index-tam-v11.js');
fs.writeFileSync(v11Path, js, 'utf8');
console.log('Saved index-tam-v11.js successfully.');


// 4. Update index.html to load index-tam-v11.js?v=11
console.log('--- Updating index.html ---');
let indexHtml = fs.readFileSync(path.join(sitePublic, 'index.html'), 'utf8');
indexHtml = indexHtml.replace(/index-tam-v\d+\.js(\?v=\d+)?/g, 'index-tam-v11.js?v=11');
fs.writeFileSync(path.join(sitePublic, 'index.html'), indexHtml, 'utf8');
console.log('index.html updated.');
