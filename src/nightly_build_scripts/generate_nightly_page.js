/**
 * Usage: node generate_nightly_page.js [<keyfile> [<outputfile> [<templatefile>]]]
 *
 * keyfile:
 *     The key.json file to use for authentication
 * outputfile:
 *     The file where to write the output to
 * templatefile:
 *     The HTML template to use, supports the following placeholders:
 *     - "{{ title }}" - will be replaced with page title
 *     - "{{ description }}" - will be replaced with page description
 *     - "{{ content }}" - will be replaced with page content
 *
 * Setup:
 *     npm install pkgcloud
 * For NodeJS < 0.10 also
 *     npm install readable-stream
 */

//~~ setup

// imports

var pkgcloud = require('pkgcloud'),
    fs = require('fs'),
    path = require('path'),
    stream = require('stream'),
    util = require('util');

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

// key file to use => ./key.json or first command line argument
var keyfile = path.join(__dirname, 'key.json');
if (process.argv.length >= 3) {
  keyfile = process.argv[2];
}

// output file => ./index.html or second command line argument
var outputfile = path.join(__dirname, 'index.html');
if (process.argv.length >= 4) {
  outputfile = process.argv[3];
}

// template file ==> ./template.html or third command line argument
var templatefile = path.join(__dirname, 'template.html');
if (process.argv.length >= 5) {
  templatefile = process.argv[4];
}

//~~ helpers

var filterByExtension = function(fileObjs, extensions) {
  return fileObjs.filter(function (obj) {
    var name = obj.name;
    return extensions.some(function (extension) { return name.endsWith(extension); })
  });
}

var filterByName = function(fileObjs, name) {
  return fileObjs.filter(function (obj) { return obj.name.startsWith(name) });
}

var filterNameByRegex = function(fileObjs, regex) {
  return fileObjs.filter(function (obj) { return regex.test(obj.name) });
}

var stripLeading = function(name, toStrip) {
  return name.substring(toStrip.length);
}

var sortByDate = function(a, b) {
  if (a.timeCreated < b.timeCreated) return 1;
  if (a.timeCreated > b.timeCreated) return -1;
  return 0;
}

var formatDate = function(date) {
  return date.replace(/T/, ' ').replace(/\..+/, '') + " UTC";
}

var formatSize = function(bytes) {
  // Formats the given file size in bytes
  if (!bytes) return "-";

  var units = ["bytes", "KB", "MB"];
  for (var i = 0; i < units.length; i++) {
      if (bytes < 1024) {
          return bytes.toFixed(1) + units[i];
      }
      bytes /= 1024;
  }
  return bytes.toFixed(1) + "GB";
}

var convertHash = function(hash) {
  // Converts a hash from base64 to hex
  return new Buffer(hash, 'base64').toString('hex');
}

var outputTable = function(fileObjs, s, nameProcessor, limit) {
  // Outputs an HTML table to <s> for the provided <fileObjs>, limiting them to <limit>
  // and preprocessing the filename with <nameProcessor>

  limit = limit || 20;

  s.write('<table class="table table-hover table-bordered">\n');
  s.write('<tr><th class="name">Name</th><th class="date">Creation Date</th><th class="size">Size</th><th class="md5sum">MD5 Hash</th></tr>\n');

  // sort by date and limit
  fileObjs.sort(sortByDate).slice(0, limit).forEach(function(fileObj) {
    console.log("Processing file object: %j", fileObj);

    var url = "https://storage.googleapis.com/octoprint/" + fileObj.name;
    var name = nameProcessor(fileObj.name);

    s.write('<tr>');
    s.write('<td class="name"><a href="' + url + '">' + name + "</a></td>");
    s.write('<td class="date">' + formatDate(fileObj.timeCreated) + "</td>");
    s.write("<td class='size'>" + formatSize(fileObj.size) + "</td>");
    s.write("<td class='md5sum'><code>" + convertHash(fileObj.md5Hash) + "</code></td>");
    s.write("</tr>\n");
  });

  s.write('</table>\n');
}

var outputPage = function(files, s) {
  // Outputs the page for <files> to stream <s>, using the template.
  var title = "OctoPi Downloads";
  var description = "OctoPi Downloads";

  var Writable = stream.Writable || require('readable-stream').Writable;
  function StringStream(options) {
    Writable.call(this, options);
    this.buffer = "";
  }
  util.inherits(StringStream, Writable);
  StringStream.prototype._write = function (chunk, enc, cb) {
    this.buffer += chunk;
    cb();
  };

  var output = new StringStream();

  output.write("<ul><li><a href='#rpi'>Raspberry Pi</a><ul><li><a href='#rpi-stable'>Stable Builds</li><li><a href='#rpi-nightly'>Nightly Builds</a></li></ul></li><li><a href='#banana'>Banana Pi M1</a><ul><li><a href='#banana-nightly'>Nightly Builds</a></li></ul></li></ul>");

  output.write("<h2 id='rpi'>Raspberry Pi</h2>\n");

  output.write("<h3 id='rpi-stable'>Stable Builds</h3>\n")
  outputTable(filterNameByRegex(files, /^stable\/.*octopi-(wheezy|jessie|stretch)-.*/),
              output,
              function(name) { return stripLeading(name, "stable/") },
              3);

  output.write("<h3 id='rpi-nightly'>Nightly Builds</h3>\n");
  output.write("<small>Warning: These builds are untested and can be unstable and/or broken. If in doubt use a stable build.</small>");
  outputTable(filterNameByRegex(files.filter(function (obj) { return !obj.name.startsWith("stable/") && !obj.name.startsWith("bananapi-m1/") }), /octopi-(wheezy|jessie|stretch)-/),
              output,
              function(name) { return name },
              14);

  output.write("<h2 id='banana'>Banana Pi M1</h2>\n")

  output.write("<h3 id='banana-nightly'>Nightly Builds</h3>\n");
  output.write("<small>Warning: These builds are untested and can be unstable and/or broken.</small>");
  outputTable(filterNameByRegex(files, /^bananapi-m1\//),
              output,
              function(name) { return stripLeading(name, "bananapi-m1/") },
              14);

  var content = output.buffer;
  fs.readFile(templatefile, "utf8", function (err, template) {
    var result = template.replace(/{{ content }}/g, content)
                         .replace(/{{ title }}/g, title)
                         .replace(/{{ description }}/g, description);
    s.write(result);
  })

}

//~~ action and go

// construct client
var client = require('pkgcloud').storage.createClient({
  provider: 'google',
  keyFilename: keyfile, // path to a JSON key file
});
var container = "octoprint";

// fetch our files and render our page
client.getFiles(container, function (err, files) {
  var stream = fs.createWriteStream(outputfile);
  outputPage(filterByExtension(files, [".zip"]), stream);
});
