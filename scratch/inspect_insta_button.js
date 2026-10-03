const fs = require('fs');
const js = fs.readFileSync('D:/My DOC/project/site/public/assets/index-tam-v10.js', 'utf8');

const idx = js.indexOf('https://www.instagram.com/tam.learn');
console.log(js.substring(idx - 100, idx + 450));
