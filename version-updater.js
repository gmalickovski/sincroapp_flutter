const fs = require('fs');
const path = require('path');

module.exports.readVersion = function (contents) {
    const versionLine = contents.split('\n').find(line => line.startsWith('version:'));
    return versionLine.split(':')[1].trim();
};

module.exports.writeVersion = function (contents, version) {
    return contents.replace(/^version:.*$/m, `version: ${version}`);
};
