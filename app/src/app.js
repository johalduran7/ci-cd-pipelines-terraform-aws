const express = require('express');
const app = express();
const port = 3000;

// Simple route to respond with "Hello World"
app.get('/', (req, res) => {
    res.send('New Version Liza: tag v1.0.2');
});

// Start the server
app.listen(port, () => {
    console.log(`Server is running on http://localhost:${port}`);
});
