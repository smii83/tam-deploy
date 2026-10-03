const fs = require('fs');

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
    <link rel="icon" type="image/svg+xml" href="/favicon.svg" />
    <script type="module" crossorigin src="/assets/index-tam-v7.js?v=7"></script>
    <link rel="stylesheet" crossorigin href="/assets/index-B6lj_HPu.css">
  </head>
  <body>
    <div id="root"></div>
  </body>
</html>
`;

fs.writeFileSync(htmlPath, htmlContent, 'utf8');
console.log('Updated index.html to load index-tam-v7.js');
