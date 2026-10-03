const fs = require('fs');
const jsContent = fs.readFileSync('D:/My DOC/project/site/public/assets/index-tam-v4.js', 'utf8');

// Find P5 (Header) and cN (Home page)
const p5Idx = jsContent.indexOf('function P5()');
const cnIdx = jsContent.indexOf('function cN()');
const lnIdx = jsContent.indexOf('function lN()');
const dnIdx = jsContent.indexOf('function dN()');

console.log('P5 idx:', p5Idx);
console.log('cN idx:', cnIdx);
console.log('lN idx:', lnIdx);
console.log('dN idx:', dnIdx);

console.log('--- Header P5 ---');
console.log(jsContent.substring(p5Idx, p5Idx + 1200));

console.log('--- Home cN ---');
console.log(jsContent.substring(cnIdx, cnIdx + 800));

console.log('--- lN (Terms Section) ---');
console.log(jsContent.substring(lnIdx, lnIdx + 400));
