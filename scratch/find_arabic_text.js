const fs = require('fs');
const jsContent = fs.readFileSync('D:/My DOC/project/site/public/assets/index-tam-v4.js', 'utf8');

const targets = ['كويت', 'سادس', '١٢ صف', '12', 'كويتي', 'كويتية', 'الكويت'];

targets.forEach(t => {
  let idx = 0;
  while ((idx = jsContent.indexOf(t, idx)) !== -1) {
    // Only print if within text/JSX (after index 400000)
    if (idx > 400000) {
      console.log(`[${t}] at ${idx}:`);
      console.log(jsContent.substring(Math.max(0, idx - 100), Math.min(jsContent.length, idx + 120)));
      console.log('---');
    }
    idx += t.length;
  }
});
