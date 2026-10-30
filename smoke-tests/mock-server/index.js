
const express = require('express');
const fs = require('fs');
const app = express();

// Records every request's headers, so smoke tests can check what the app sent (for example
// whether a `traceparent` header was injected).
const requestLog = process.env.REQUEST_LOG || 'requests.jsonl';
app.use((req, res, next) => {
  fs.appendFileSync(requestLog, JSON.stringify({ method: req.method, url: req.url, headers: req.headers }) + '\n');
  next();
});
const port = 1080;

app.get('/simple-api', (req, res) => {
  res.send('this is the api response');
})

app.listen(port, () => {
  console.log(`Listening on port ${port}`)
})
