const express = require('express');
const app = express();
const port = 3000;

// Simple route to respond with "Hello World"
app.get('/', (req, res) => {
    res.send('Hello World from Node.js app');
});

// Start the server
app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
});
