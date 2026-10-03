const fs = require('fs');

function fixFooterFile(filePath) {
  let content = fs.readFileSync(filePath, 'utf8');

  // Search for the footer container
  const oldContainer = 'x.jsx("div",{className:"border-t py-6 text-center",style:{borderColor:"hsl(0,0%,100%,0.10)"}';
  const newContainer = 'x.jsx("div",{className:"border-t py-6 text-center relative z-10",style:{borderColor:"hsl(0,0%,100%,0.10)"}';

  if (content.includes(oldContainer)) {
    content = content.replace(oldContainer, newContainer);
    console.log(`Updated container in ${filePath} to have relative z-10!`);
  } else {
    console.log(`Could not find old container directly in ${filePath}, searching patterns...`);
    const regex = /className:"border-t py-6 text-center"/g;
    content = content.replace(regex, 'className:"border-t py-6 text-center relative z-10"');
    console.log(`Applied regex replacement in ${filePath}`);
  }

  fs.writeFileSync(filePath, content, 'utf8');
}

fixFooterFile('D:/My DOC/project/site/public/assets/index-tam-v3.js');
fixFooterFile('D:/My DOC/project/site/public/assets/index-klBE3b22.js');
