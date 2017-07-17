/**
 * Usage: node cleanup_storage.js <action> [<keyfile>]
 *
 * action:
 *     "print" or "delete"
 * keyfile:
 *     The key.json file to use for authentication
 *
 * Setup:
 *     npm install pkgcloud
 */

//~~ setup

// imports

var pkgcloud = require('pkgcloud'),
    fs = require('fs'),
    path = require('path');

// polyfills

if (!String.prototype.startsWith) {
  String.prototype.startsWith = function (str) {
      return !this.indexOf(str);
  }
}

if (!String.prototype.endsWith) {
  String.prototype.endsWith = function(searchString, position) {
      var subjectString = this.toString();
      if (typeof position !== 'number' || !isFinite(position) || Math.floor(position) !== position || position > subjectString.length) {
        position = subjectString.length;
      }
      position -= searchString.length;
      var lastIndex = subjectString.indexOf(searchString, position);
      return lastIndex !== -1 && lastIndex === position;
  };
}

//~~ argument parsing

// "delete" -> delete, "print" -> only print
if (process.argv.length < 3) {
  console.log("Missing mandatory action parameter");
  process.exit();
}
var action = process.argv[2];

// key file to use => ./key.json or second command line argument
var keyfile = path.join(__dirname, 'key.json');
if (process.argv.length >= 4) {
  keyfile = process.argv[3];
}

//~~ helpers

var sortByDate = function(a, b) {
  if (a.timeCreated < b.timeCreated) return 1;
  if (a.timeCreated > b.timeCreated) return -1;
  return 0;
}

//~~ action and go

// construct client
var client = require('pkgcloud').storage.createClient({
  provider: 'google',
  keyFilename: keyfile, // path to a JSON key file
});
var container = "octoprint";

// fetch our files and render our page
var matchers = [
  {
    matcher: function(obj) { return !obj.name.startsWith("stable/") && !obj.name.startsWith("bananapi-m1/") && /octopi-(wheezy|jessie)-/.test(obj.name); },
    limit: 14
  },
  {
    matcher: function(obj) { return /^bananapi-m1\//.test(obj.name); },
    limit: 14
  }
]

var now = new Date();
client.getFiles(container, function (err, files) {
  matchers.forEach(function(m) {
    var cutoff = new Date();
    cutoff.setDate(now.getDate() - m.limit);

    var filesToDelete = files.filter(m.matcher)
                             .filter(function(obj) { return new Date(Date.parse(obj.timeCreated)) < cutoff });

    filesToDelete.forEach(function (file) {
      if (action == "delete") {
        client.removeFile(container, encodeURIComponent(file.name), function(err) {
          if (err) {
            console.log("Error deleting " + file.name + ": " + err);
          } else {
            console.log("Deleted " + file.name + " on " + container);
          }
        });
      } else {
        console.log("Would now delete " + file.name + " on " + container);
      }
    });
  });
});
