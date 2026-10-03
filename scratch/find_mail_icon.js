const fs = require('fs');
const js = fs.readFileSync('D:/My DOC/project/site/public/assets/index-tam-v10.js', 'utf8');

// Find icon definitions (e.g. mail, at-sign, etc.)
['mail', 'envelope', 'message', 'inbox', 'send'].forEach(name => {
  let idx = 0;
  while ((idx = js.indexOf(`"${name}"`, idx)) !== -1) {
    const start = Math.max(0, idx - 100);
    const end = Math.min(js.length, idx + 100);
    console.log(`Found icon "${name}" at ${idx}:\n${js.substring(start, end)}\n---`);
    idx += name.length + 2;
  }
});

// Let's also search for where the instagram button is located in context
const instaIdx = js.indexOf('tam.learn');
console.log('Instagram context:\n', js.substring(instaIdx - 200, instaIdx + 400));
