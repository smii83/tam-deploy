const fs = require('fs');

const jsContent = fs.readFileSync('D:/My DOC/project/site/public/assets/index-tam-v3.js', 'utf8');
fs.writeFileSync('D:/My DOC/project/site/public/assets/index-tam-v4.js', jsContent, 'utf8');

const htmlPath = 'D:/My DOC/project/site/public/index.html';
const htmlContent = `<!DOCTYPE html>
<html lang="ar" dir="rtl">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1" />
    <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate" />
    <meta http-equiv="Pragma" content="no-cache" />
    <meta http-equiv="Expires" content="0" />
    <title>تَم - منصة تعليمية كويتية</title>
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <script type="module" crossorigin src="/assets/index-tam-v4.js?v=4"></script>
    <link rel="stylesheet" crossorigin href="/assets/index-B6lj_HPu.css">
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
`;
fs.writeFileSync(htmlPath, htmlContent, 'utf8');
console.log('Saved index-tam-v4.js and updated index.html');
