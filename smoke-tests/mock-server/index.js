
const express = require('express');
const app = express();
const port = 1080;

app.get('/simple-api', (req, res) => {
  res.send('this is the api response');
})

app.listen(port, () => {
  console.log(`Listening on port ${port}`)
})
