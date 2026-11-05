
const express = require('express');
const app = express();
const port = 1080;

app.get('/simple-api', (req, res) => {
  res.send('this is the api response');
})

// Used by the smoke tests for the URLSession request filter, span name provider and error status.
app.get('/filtered-api', (req, res) => {
  res.send('this request is filtered out of the traces');
})

app.get('/named-api/:id', (req, res) => {
  res.send(`this is the response for ${req.params.id}`);
})

app.get('/error-api', (req, res) => {
  res.status(500).send('this is an error response');
})

app.listen(port, () => {
  console.log(`Listening on port ${port}`)
})
