const fs = require('fs');

const js = fs.readFileSync('D:/My DOC/project/site/public/assets/index-tam-v8.js', 'utf8');

const p5Idx = js.indexOf('function P5()');
console.log('=== P5 code ===');
console.log(js.substring(p5Idx, p5Idx + 1500));
