const fs = require('fs');
const jsContent = fs.readFileSync('D:/My DOC/project/site/public/assets/index-tam-v4.js', 'utf8');

function printSection(name, startStr, length = 1500) {
  const idx = jsContent.indexOf(startStr);
  console.log(`=== ${name} (at ${idx}) ===`);
  if (idx !== -1) {
    console.log(jsContent.substring(idx, idx + length));
  } else {
    console.log('NOT FOUND');
  }
}

printSection('Hero G5', 'function G5()');
printSection('Features Z5', 'function Z5()');
printSection('AI Tutor $5', 'function $5()');
printSection('Camera eN', 'function eN()');
printSection('Reviews iN', 'function iN()');
printSection('Download & Footer aN', 'function aN()');
