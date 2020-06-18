#!/usr/local/bin/node

'use strict;'

const azure = require('azure-storage');
const program = require('commander');
const readline = require('readline');

const PERSISTENT = 'persistent-storage';

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout
});

let done = -1;

function usage() {
  console.info('restore --in-group <in-group> --in-account <in-account> --blob <blob-name> --out-group <out-group> --out-account <out-account>');
  process.exit(-1);
}

function doCheck(service, containerName, blobName) {
  const checkInterval = setInterval(() => {
    service.getBlobProperties(containerName, blobName, null, (err, res) => {
      switch (res.copy.status) {
        case 'pending':
          console.log(`Copied ${properties.bytesCopied} of ${properties.totalBytes}`);
          break;
        case 'success':
          console.log('Done!!!')
          clearInterval(checkInterval);
          done = 0;
          break;
        case 'failed':
          clearInterval(checkInterval);
          done = 1;
          break;
        case 'aborted':
          clearInterval(checkInterval);
          done = 1;
          break;
        default:
      }
    });
  }, 15000)
}

program
  .version('1.0.0')
  .option('--in-group <required>', 'Source resource group')
  .option('--in-account <required>', 'Source storage account')
  .option('--blob <required>', 'BLOB Name')
  .option('--out-group <required>', 'Destination resource group')
  .option('--out-account <required>', 'Destination storage account')
  .parse(process.argv);


if (!program.inGroup ||
    !program.inAccount ||
    !program.blob ||
    !program.outGroup ||
    !program.outAccount) {
  usage();
}

const { execSync } = require('child_process');

let result =  execSync('login-azure.sh').toString();

result = execSync(`az storage account keys list -n ${program.inAccount} -g ${program.inGroup} | jq -r '.[].value'`).toString();
const srcKeys = result.split("\n");
const srcService = new azure.BlobService(program.inAccount, srcKeys[0]);

result = execSync(`az storage account keys list -n ${program.outAccount} -g ${program.outGroup} | jq -r '.[].value'`).toString();
const destKeys = result.split("\n");
const destService = new azure.BlobService(program.outAccount, destKeys[0]);

let blobSegments = program.blob.split("/");
if (blobSegments.length < 3) {
  console.log(`Invalid blob name ${program.blob}`);
  process.exit(1);
}
const container = blobSegments[0];
const blobName = program.blob.slice(container.length + 1);
let opts = { "include": "snapshots,metadata" };
srcService.listBlobsSegmentedWithPrefix(container, blobName, null, opts, (err, res) => {
  if (err) {
    console.error('Fetching Snapshot Info: ', err);
    done = 1;
  }
  if (!res.entries) {
    console.error('No entries');
    done = 1;
  }
  const snapshots = [];
  res.entries.forEach(back => {
    if (back.snapshot) {
      snapshots.push(back.snapshot);
      snapshots.sort();
    }
  });

  for (let i = 0; i < snapshots.length; i++) {
    console.log(`${i}) ${snapshots[i]}`);
  }
  console.log('-1) QUIT');

  rl.question('Enter the number of the snapshot to copy: ', (answer) => {
    if (isNaN(answer) || answer < -1 || answer > (snapshots.length - 1)) {
      answer = -1;
    }
    if (answer == -1) {
      console.log('Copy cancelled');
      done = 0
    } else {
      let uri = srcService.getUrl(container, blobName);

      let slicePos = 0;
      if (blobName.startsWith(`${PERSISTENT}/`)) {
        slicePos = PERSISTENT.length + 1;
      }
      destService.createContainerIfNotExists(PERSISTENT, null, (err, res) => {
        if (err) {
          console.err(`Unable to create container: ${err}`);
          done = 1;
        } else {
          console.log(`Creating ${res}`);
          opts = { };
          opts.snapshotId = snapshots[answer];
          destService.startCopyBlob(uri, PERSISTENT, blobName.slice(slicePos), opts, (err, res) => {
            if (err) {
              console.error(`Error copying blob: ${err}`);
              done = 1;
            } else {
              doCheck(destService, PERSISTENT, blobName.slice(slicePos));
            }
          });
        }
      });
    }
  });
});

const doneInterval = setInterval(() => {
  if (done != -1) {
    clearInterval(doneInterval);
    execSync('az logout');
    process.exit(done);
  }
}, 1000);

