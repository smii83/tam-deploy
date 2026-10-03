const fs = require('fs');
const jsContent = fs.readFileSync('D:/My DOC/project/site/public/assets/index-tam-v4.js', 'utf8');
const idx = jsContent.indexOf('function G5()');
console.log(jsContent.substring(idx, idx + 2500));
