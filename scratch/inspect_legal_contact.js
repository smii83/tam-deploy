const fs = require('fs');

const terms = fs.readFileSync('D:/My DOC/project/site/public/terms.html', 'utf8');
const privacy = fs.readFileSync('D:/My DOC/project/site/public/privacy.html', 'utf8');

const tIdx = terms.indexOf('id="contact"');
console.log('=== TERMS CONTACT ===\n', terms.substring(tIdx, tIdx + 1000));

const pIdx = privacy.indexOf('id="contact"');
console.log('=== PRIVACY CONTACT ===\n', privacy.substring(pIdx, pIdx + 1000));
