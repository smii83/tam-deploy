const fs = require('fs');
const path = require('path');

const indexHtml = fs.readFileSync('D:/My DOC/project/site/public/index.html', 'utf8');
console.log('=== index.html content ===\n', indexHtml);

// Find which index-tam-v*.js is currently used:
const match = indexHtml.match(/index-tam-v\d+\.js/);
const currentJs = match ? match[0] : 'index-tam-v9.js';
console.log('Current JS in index.html:', currentJs);

const jsPath = path.join('D:/My DOC/project/site/public/assets', currentJs);
const jsContent = fs.readFileSync(jsPath, 'utf8');

console.log('=== Searching in', currentJs, '===');
['instagram', 'tam.learn', '@tam', 'انستغرام', 'الانستغرام'].forEach(term => {
  let idx = 0;
  while ((idx = jsContent.toLowerCase().indexOf(term.toLowerCase(), idx)) !== -1) {
    const start = Math.max(0, idx - 150);
    const end = Math.min(jsContent.length, idx + 150);
    console.log(`Found "${term}" at ${idx}:\n${jsContent.substring(start, end)}\n---`);
    idx += term.length;
  }
});
