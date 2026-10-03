const fs = require('fs');

function checkFile(path) {
  const content = fs.readFileSync(path, 'utf8');
  console.log(`=== Checking ${path} ===`);
  const keywords = ['كويت', 'كويتي', 'كويتية', 'الكويت', 'Kuwait', 'سادس', 'من 6', '6 إلى 12'];
  keywords.forEach(kw => {
    let idx = 0;
    while ((idx = content.indexOf(kw, idx)) !== -1) {
      console.log(`[${kw}] at ${idx}: ...${content.substring(Math.max(0, idx - 40), Math.min(content.length, idx + 60))}...`);
      idx += kw.length;
    }
  });
}

checkFile('c:/Users/smiip/OneDrive/Desktop/TAM/admin_dashboard/terms.html');
checkFile('c:/Users/smiip/OneDrive/Desktop/TAM/admin_dashboard/privacy.html');
