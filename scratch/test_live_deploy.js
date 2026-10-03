const https = require('https');

function fetchUrl(url) {
  return new Promise((resolve, reject) => {
    https.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve({ statusCode: res.statusCode, data }));
    }).on('error', reject);
  });
}

async function test() {
  console.log('Testing live deployment on website-tam-4a01b.web.app...');
  
  const termsRes = await fetchUrl('https://website-tam-4a01b.web.app/terms.html');
  console.log('terms.html status:', termsRes.statusCode);
  console.log('terms has support@codecore.llc:', termsRes.data.includes('support@codecore.llc'));
  console.log('terms has support.codecore@gmail.com:', termsRes.data.includes('support.codecore@gmail.com'));
  console.log('terms has instagram.com:', termsRes.data.includes('instagram.com'));

  const privacyRes = await fetchUrl('https://website-tam-4a01b.web.app/privacy.html');
  console.log('privacy.html status:', privacyRes.statusCode);
  console.log('privacy has support@codecore.llc:', privacyRes.data.includes('support@codecore.llc'));
  console.log('privacy has support.codecore@gmail.com:', privacyRes.data.includes('support.codecore@gmail.com'));
  console.log('privacy has instagram.com:', privacyRes.data.includes('instagram.com'));

  const indexRes = await fetchUrl('https://website-tam-4a01b.web.app/index.html');
  console.log('index.html status:', indexRes.statusCode);
  console.log('index.html references index-tam-v11.js:', indexRes.data.includes('index-tam-v11.js'));

  const jsRes = await fetchUrl('https://website-tam-4a01b.web.app/assets/index-tam-v11.js');
  console.log('index-tam-v11.js status:', jsRes.statusCode);
  console.log('js has mailto:support@codecore.llc:', jsRes.data.includes('mailto:support@codecore.llc'));
  console.log('js has instagram:', jsRes.data.includes('تابعنا على الانستغرام'));
}

test().catch(console.error);
