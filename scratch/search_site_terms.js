const fs = require('fs');
const path = require('path');

function searchDir(dir, query) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      searchDir(fullPath, query);
    } else if (entry.isFile()) {
      if (fullPath.endsWith('.js') || fullPath.endsWith('.html') || fullPath.endsWith('.css') || fullPath.endsWith('.json')) {
        const content = fs.readFileSync(fullPath, 'utf8');
        let idx = 0;
        while ((idx = content.toLowerCase().indexOf(query.toLowerCase(), idx)) !== -1) {
          const start = Math.max(0, idx - 80);
          const end = Math.min(content.length, idx + 80);
          console.log(`[${fullPath}] match at ${idx}:\n...${content.substring(start, end).replace(/\n/g, ' ')}...\n`);
          idx += query.length;
        }
      }
    }
  }
}

console.log('=== SEARCHING FOR INSTAGRAM ===');
searchDir('D:/My DOC/project/site/public', 'instagram');

console.log('=== SEARCHING FOR TAM.LEARN ===');
searchDir('D:/My DOC/project/site/public', 'tam.learn');

console.log('=== SEARCHING FOR SUPPORT ===');
searchDir('D:/My DOC/project/site/public', 'support');
