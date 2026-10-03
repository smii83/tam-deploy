const fs = require('fs');

// Read the official app logo
const logoBuffer = fs.readFileSync('D:/My DOC/project/site/public/assets/logo-D-XQ31zw.jpeg');

// Save as favicon.png and apple-touch-icon.png in public
fs.writeFileSync('D:/My DOC/project/site/public/favicon.png', logoBuffer);
fs.writeFileSync('D:/My DOC/project/site/public/favicon.ico', logoBuffer);
fs.writeFileSync('D:/My DOC/project/site/public/apple-touch-icon.png', logoBuffer);

// Also copy to admin_dashboard
fs.writeFileSync('c:/Users/smiip/OneDrive/Desktop/TAM/admin_dashboard/favicon.png', logoBuffer);
fs.writeFileSync('c:/Users/smiip/OneDrive/Desktop/TAM/admin_dashboard/favicon.ico', logoBuffer);
fs.writeFileSync('c:/Users/smiip/OneDrive/Desktop/TAM/admin_dashboard/apple-touch-icon.png', logoBuffer);

// Create an SVG favicon that embeds the logo cleanly as base64 with rounded corners
const base64Logo = logoBuffer.toString('base64');
const svgFavicon = `<svg width="180" height="180" viewBox="0 0 180 180" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <clipPath id="roundCorner">
      <rect width="180" height="180" rx="40" ry="40" />
    </clipPath>
  </defs>
  <rect width="180" height="180" rx="40" fill="#4F46E5"/>
  <image href="data:image/jpeg;base64,${base64Logo}" width="180" height="180" clip-path="url(#roundCorner)" preserveAspectRatio="xMidYMid slice" />
</svg>`;

fs.writeFileSync('D:/My DOC/project/site/public/favicon.svg', svgFavicon, 'utf8');
fs.writeFileSync('c:/Users/smiip/OneDrive/Desktop/TAM/admin_dashboard/favicon.svg', svgFavicon, 'utf8');

console.log('Successfully created all favicon formats with TAM app logo!');

// Update index.html
const htmlPath = 'D:/My DOC/project/site/public/index.html';
const htmlContent = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1" />
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
    <meta http-equiv="Pragma" content="no-cache" />
    <meta http-equiv="Expires" content="0" />
    <title>تَم - منصة تعليمية ذكية</title>
    <link rel="icon" type="image/png" href="/favicon.png?v=logo" />
    <link rel="shortcut icon" type="image/png" href="/favicon.png?v=logo" />
    <link rel="apple-touch-icon" href="/apple-touch-icon.png?v=logo" />
    <script type="module" crossorigin src="/assets/index-tam-v9.js?v=9"></script>
    <link rel="stylesheet" crossorigin href="/assets/index-B6lj_HPu.css">
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
`;
fs.writeFileSync(htmlPath, htmlContent, 'utf8');
console.log('Updated index.html favicon tags');

// Update terms.html and privacy.html favicon tags
function updateLegalFavicons(filePath) {
  let content = fs.readFileSync(filePath, 'utf8');
  if (!content.includes('rel="icon"')) {
    content = content.replace(
      '<link rel="stylesheet" href="legal.css" />',
      '<link rel="icon" type="image/png" href="/favicon.png?v=logo" />\n  <link rel="apple-touch-icon" href="/apple-touch-icon.png?v=logo" />\n  <link rel="stylesheet" href="legal.css" />'
    );
  }
  fs.writeFileSync(filePath, content, 'utf8');
}

updateLegalFavicons('D:/My DOC/project/site/public/terms.html');
updateLegalFavicons('D:/My DOC/project/site/public/privacy.html');
updateLegalFavicons('c:/Users/smiip/OneDrive/Desktop/TAM/admin_dashboard/terms.html');
updateLegalFavicons('c:/Users/smiip/OneDrive/Desktop/TAM/admin_dashboard/privacy.html');
console.log('Updated legal HTML favicon tags');
