  var pkgcloud = require('pkgcloud'), fs = require('fs'), path = require('path');
  
  if(!String.prototype.startsWith){
    String.prototype.startsWith = function (str) {
        return !this.indexOf(str);
    }
}
  
  var client = require('pkgcloud').storage.createClient({
   provider: 'google',
   keyFilename: path.join(__dirname, 'key.json'), // path to a JSON key file
   //#projectId: 'eco-channel-658' // project id
});
  
  var cointainer = "octoprint";
  
  client.getFiles(cointainer, function (err, files) { 
   
  var stream = fs.createWriteStream(path.join(__dirname, 'index.html'));
  
      
  stream.write("<html><title>OctoPrint Nightly builds</title><body><h1>OctoPi Nightly Builds</h1><table>\n");
  files.sort(function(a,b) {
       if (a.name.startsWith("bananapi") && b.name.startsWith("octopi")) return 1;
       if (b.name.startsWith("bananapi") && a.name.startsWith("octopi")) return -1;
       if(a.timeCreated < b.timeCreated) return 1;
       if(a.timeCreated > b.timeCreated) return -1;
       return 0;   
  }
).forEach(function(fileObj) {
        
    stream.write('<tr><td><a href="https://storage.googleapis.com/octoprint/' + fileObj.name + ' " >' + fileObj.name + "</a> <td>" + fileObj.timeCreated +" </td></td></tr>\n");
    });
    stream.write("</table></body></html>\n");
            
  });