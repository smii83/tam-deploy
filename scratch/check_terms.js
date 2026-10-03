const fs = require('fs');
const content = fs.readFileSync('D:/My DOC/project/site/public/assets/index-klBE3b22.js', 'utf8');
const indices = [];
let idx = 0;
while ((idx = content.indexOf('terms', idx)) !== -1) {
  indices.push(idx);
  idx += 5;
}
console.log('Terms occurrences count:', indices.length);
indices.forEach((i, count) => {
  console.log(`--- Occurrence ${count + 1} at ${i} ---`);
  console.log(content.substring(Math.max(0, i - 100), Math.min(content.length, i + 100)));
});
