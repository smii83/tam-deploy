const fs = require('fs');

const js = fs.readFileSync('D:/My DOC/project/site/public/assets/index-tam-v7.js', 'utf8');

const z5Idx = js.indexOf('function Z5()');
console.log('=== Z5 code ===');
console.log(js.substring(z5Idx, z5Idx + 2000));

const y5Idx = js.indexOf('const Y5=');
console.log('=== Y5 code ===');
console.log(js.substring(y5Idx, y5Idx + 1500));
