const fs = require('fs');
const yaml = require('js-yaml');
const execSync = require('child_process').execSync;
const k8sMain = require('./k8s-main');
const processed = k8sMain.processed;

module.exports = (args) => {
  if (!args.procfile || !fs.existsSync(args.procfile)) {
    console.error('Missing path to processes_all_separate.json file');
    return;
  }

  if (!args.repodir || !fs.existsSync(args.repodir)) {
    console.error('Missing repository directory to output configs to.');
    return;
  }

  let pasData;
  try {
    const rawData = fs.readFileSync(args.procfile);
    pasData = JSON.parse(rawData);
  }
  catch (error) {
    console.error(`Unable to read data from ${args.procfile}.  Reason: ${error}`);
    return;
  }

  pasData.apps.forEach(app => {
    if (processed.app[app.name]) {
      processed.app[app.name]++;
    }
    else {
      console.log(`Working on app: ${app.name}`);
      if (!processed.configMapFiles.shared) {
        processed.configMapFiles.shared = k8sMain.generateSharedMapFile(app.env);
      }
      k8sMain.processApplication[k8sMain.toCamelCase(app.name)](app.name, app.env);
    }
  });

  for (let app in processed.app) {
    console.log(`${app} x${processed.app[app]}`);
  }

  console.log('=======================');
  console.log('Writing configmaps');
  for (let index in processed.configMapFiles) {
    const configMap = processed.configMapFiles[index];
    const dir = `${args.repodir}/projects/nucleus/${configMap.directory}`;
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir);
    }
    console.log(`    ${dir}/${configMap.writeTo}`)
    fs.writeFileSync(`${dir}/${configMap.writeTo}`, yaml.dump(configMap.configMap));
  }

  console.log('=======================');
  console.log('Writing secrets')
  const dir = `${process.env.deploymentDir}/${process.env.secretsDir}`
  for (let index in processed.secretFiles) {
    const secret = processed.secretFiles[index];
    console.log(`    ${dir}/${secret.writeTo}`)
    fs.writeFileSync(`${dir}/${secret.writeTo}`, yaml.dump(secret.secret));
  }
};
