const fs = require('fs');
const js = fs.readFileSync('D:/My DOC/project/site/public/assets/index-tam-v5.js', 'utf8');

const p5Idx = js.indexOf('function P5()');
console.log(js.substring(p5Idx, p5Idx + 2000));
