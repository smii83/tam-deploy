const fs = require('fs');

const js = fs.readFileSync('D:/My DOC/project/site/public/assets/index-tam-v7.js', 'utf8');

const z5Idx = js.indexOf('function Z5()');
console.log(js.substring(z5Idx + 800, z5Idx + 2200));
