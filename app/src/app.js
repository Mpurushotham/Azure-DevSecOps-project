// simple express app
const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => res.send('Hello from Azure DevSecOps example (GitOps)!'));
app.get('/health', (req, res) => res.status(200).json({ status: 'ok' }));

app.listen(port, () => console.log(`Listening on ${port}`));
