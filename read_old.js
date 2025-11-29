const fs = require('fs');
const content = fs.readFileSync('functions/old_index.js', 'utf16le');
console.log(content);
