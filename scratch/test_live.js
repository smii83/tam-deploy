const https = require('https');

function checkUrl(url) {
  return new Promise((resolve) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          length: data.length,
          hasCodeCore: data.includes('CodeCore'),
          hasPrivacy: data.includes('privacy.html'),
          hasTerms: data.includes('terms.html'),
          snippet: data.substring(0, 300)
        });
      });
    }).on('error', (err) => resolve({ error: err.message }));
  });
}

async function run() {
  console.log('--- Checking https://www.tamlearn.com/ ---');
  console.log(await checkUrl('https://www.tamlearn.com/'));
  
  console.log('--- Checking https://www.tamlearn.com/terms.html ---');
  console.log(await checkUrl('https://www.tamlearn.com/terms.html'));

  console.log('--- Checking https://www.tamlearn.com/privacy.html ---');
  console.log(await checkUrl('https://www.tamlearn.com/privacy.html'));

  console.log('--- Checking https://www.tamlearn.com/assets/index-klBE3b22.js ---');
  console.log(await checkUrl('https://www.tamlearn.com/assets/index-klBE3b22.js'));
}

run();
