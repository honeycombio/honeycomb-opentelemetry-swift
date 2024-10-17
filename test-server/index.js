
const express = require('express');
const app = express();
const port = 3000;

app.get('/', (req, res) => {
  res.send('This is a test server.');
})

// An endpoint for testing GET requests.
app.get('/get', (req, res) => {
  res.send('success!');
})

// An endpoint for testing POST requests.
app.post('/post', (req, res) => {
  res.send('success!');
})

// An endpoint that returns an error status code.
app.get('/not_found', (req, res) => {
  res.sendStatus(404);
})

// An endpoint that takes >5s to respond.
app.get('/slow', async (req, res) => {
  await new Promise(resolve => setTimeout(resolve, 5000));
  res.send('success! eventually.');
})

app.listen(port, () => {
  console.log(`Listening on port ${port}`)
})

