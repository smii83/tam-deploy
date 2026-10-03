const fs = require('fs');
const path = require('path');

const sitePublic = 'D:/My DOC/project/site/public';

console.log('=== VERIFYING SITE TERMS.HTML ===');
const terms = fs.readFileSync(path.join(sitePublic, 'terms.html'), 'utf8');
console.log('terms has old gmail:', terms.includes('support.codecore@gmail.com'));
console.log('terms has new email:', terms.includes('support@codecore.llc'));
console.log('terms has instagram:', terms.includes('instagram.com'));

console.log('=== VERIFYING SITE PRIVACY.HTML ===');
const privacy = fs.readFileSync(path.join(sitePublic, 'privacy.html'), 'utf8');
console.log('privacy has old gmail:', privacy.includes('support.codecore@gmail.com'));
console.log('privacy has new email:', privacy.includes('support@codecore.llc'));
console.log('privacy has instagram:', privacy.includes('instagram.com'));

console.log('=== VERIFYING SITE INDEX-TAM-V11.JS ===');
const js = fs.readFileSync(path.join(sitePublic, 'assets/index-tam-v11.js'), 'utf8');
console.log('js has old gmail:', js.includes('support.codecore@gmail.com'));
console.log('js has new email:', js.includes('support@codecore.llc'));
console.log('js has instagram button:', js.includes('تابعنا على الانستغرام'));
console.log('js has mail button:', js.includes('mailto:support@codecore.llc'));

console.log('=== VERIFYING INDEX.HTML ===');
const indexHtml = fs.readFileSync(path.join(sitePublic, 'index.html'), 'utf8');
console.log('indexHtml script tag:', indexHtml.match(/src="[^"]+"/)[0]);
