const fs = require('fs');

const jsPath = 'D:/My DOC/project/site/public/assets/index-tam-v4.js';
const jsContent = fs.readFileSync(jsPath, 'utf8');

// Find all matches for terms like كويت, صف, 12, etc.
const keywords = ['كويت', 'كويتي', 'كويتية', 'الكويت', 'Kuwait', 'سادس', '١٢', '12 صف', '12', 'المناهج', 'terms'];

keywords.forEach(kw => {
  let count = 0;
  let idx = 0;
  console.log(`=== Keyword: "${kw}" ===`);
  while ((idx = jsContent.indexOf(kw, idx)) !== -1) {
    count++;
    console.log(`[${count}] at ${idx}: ...${jsContent.substring(Math.max(0, idx - 60), Math.min(jsContent.length, idx + 80))}...`);
    idx += kw.length;
  }
  console.log(`Total for "${kw}": ${count}\n`);
});
