const minimist = require('minimist')

module.exports = () => {
  const args = minimist(process.argv.slice(2))

  let cmd = args._[0] || 'help';

  if (args.help || args.h) {
    cmd = 'help';
  }

  if (args.version || args.v) {
    cmd = 'version';
  }
  
  switch (cmd) {
    case 'help' :
      require('./cmds/help')(args);
      break;
      
    case 'k8s' :
      require ('./cmds/k8s')(args);
      break;
    
    case 'version' :
      require('./cmds/version')(args);
      break;
    
    default:
      console.error(`Unknown command: ${cmd}`);
      break;
  }
}
