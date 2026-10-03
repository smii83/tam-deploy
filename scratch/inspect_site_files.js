const fs = require('fs');
const path = require('path');

const siteDir = 'D:/My DOC/project/site/public';
try {
  const files = fs.readdirSync(siteDir);
  console.log('Files in public:', files);
  if (fs.existsSync(path.join(siteDir, 'index.html'))) {
    const html = fs.readFileSync(path.join(siteDir, 'index.html'), 'utf8');
    console.log('index.html size:', html.length);
  }
} catch(e) {
  console.error('Error:', e.message);
}
