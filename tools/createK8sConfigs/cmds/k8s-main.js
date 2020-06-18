const processed = {
    app: {},
    configMapFiles: {},
    secretFiles: {}
};

function toCamelCase(string) {
  return string.replace(/-([a-z])/gi, (s, g1) => { return g1.toUpperCase(); });
}
  
function configMap(name, src, fields) {
  const configMap = {
    apiVersion: 'v1',
    kind: 'ConfigMap',
    metadata: {
      name,
      namespace: 'nucleus'
    },
    data: {}
  };
  fields.forEach(field => {
    if (src[field]) {
      configMap.data[field] = src[field];
    }
  });
  return configMap;
}

function secretFile(name, src, fields) {
  const secret = {
    apiVersion: 'v1',
    kind: 'Secret',
    metadata: {
      name,
      namespace: 'nucleus'
    },
    type: 'Opaque',
    data: {}
  };
  fields.forEach(field => {
    if (src[field]) {
      const strippedString = JSON.stringify(src[field]).replace(/^"(.+)"$/, '$1');
      secret.data[field] = Buffer.from(strippedString).toString('base64');
    }
  });
  return secret;
}

function generateConfigMap(name, appEnv, port, { root_url } = {}) {
  const fields = [ 'NUCLEUS_LOG_INFO', 'NUCLEUS_SERVICE_ROLE'];
  const cmap = configMap(`${name}-config`, appEnv, fields);
  cmap.data.PORT = port;
  if (root_url) {
    cmap.data.ROOT_URL = root_url;
  }
  return {
    directory: toCamelCase(name),
    writeTo: `${name}-config.yaml`,
    configMap: cmap
  };
}

function generatePipelineSecret(appEnv) {
  const fields = [ 'METEOR_SETTINGS' ];
  return {
    directory: 'secrets',
    writeTo: 'processing-pipeline-secrets.yaml',
    secret: secretFile('processing-pipeline-secrets', appEnv, fields)
  };
}

function generatePipelineConfig(which, name, appEnv) {
    processed.configMapFiles[which] = generateConfigMap(name, appEnv, '0');
    if (!processed.secretFiles.pipelineProcessing) {
      processed.secretFiles.pipelineProcessing = generatePipelineSecret(appEnv);
    }
    processed.app[name] = 1;
}

function generateSharedMapFile(appEnv) {
  const fields = [ 'NODE_ENV', 'ROOT_URL', 'MONITOR_HOST', 'MONITOR_PROTOCOL', 'PHANTOMJS_PATH'];
  appEnv.ROOT_URL = appEnv.ROOT_URL.replace('_', '-');
  return {
    directory: 'shared',
    writeTo:   'shared-config.yaml',
    configMap:  configMap('shared-config', appEnv, fields)
  }
}

const processApplication = {
  backup(name, appEnv) {
    // 1st org should be name, but this name is 'backup' instead of 'backup-service'
    processed.configMapFiles.backupService = generateConfigMap("backup-service", appEnv, '80');
    processed.secretFiles.backupServiceSecret = {
      directory: 'secrets',
      writeTo:   'backup-service-secret.yaml',
      secret:     secretFile('backup-service-secret', appEnv, [ 'METEOR_SETTINGS' ])
    };
    processed.app[name] = 1;
    return;
  },

  chunkFrameExtraction(name, appEnv) {
    generatePipelineConfig('chunkFrameExtraction', name, appEnv);
  },

  edgeServerDdp(name, appEnv) {
    const cmap = generateConfigMap(name, appEnv, '80');
    cmap.configMap.data.IS_EDGE_SERVER = appEnv.IS_EDGE_SERVER;
    processed.configMapFiles.edgeServerDdp = cmap;
    processed.secretFiles.edgeServerDdpSecret = {
      directory: 'secrets',
      writeTo:   'edge-server-ddp-secret.yaml',
      secret:     secretFile('edge-server-ddp-secret', appEnv, [ 'METEOR_SETTINGS' ])
    };
    processed.app[name] = 1;
    return;
  },

  imageDataService(name, appEnv) {
    processed.configMapFiles.imageDataService = generateConfigMap(name, appEnv, '80');
    processed.secretFiles.imageServiceSecret = {
      directory: 'secrets',
      writeTo:   'image-service-secret.yaml',
      secret:     secretFile('image-service-secret', appEnv, [ 'METEOR_SETTINGS' ])
    };
    processed.app[name] = 1;
    return;
  },

  imageViewerService(name, appEnv) {
    const cmap = generateConfigMap(name, appEnv, '80');
    cmap.configMap.data.CAPTCHA_VERIFY_SITE = appEnv.CAPTCHA_VERIFY_SITE;
    cmap.configMap.data.ROOT_URL = appEnv.ROOT_URL;
    processed.configMapFiles.imageViewerService = cmap;
    processed.app[name] = 1;
    return;
  },

  meteorUiDdp(name, appEnv) {
    const cmap = generateConfigMap(name, appEnv, '80');
    cmap.configMap.data.CAPTCHA_VERIFY_SITE = appEnv.CAPTCHA_VERIFY_SITE;
    processed.configMapFiles.meteorUiDdpService = cmap;
    processed.secretFiles.completeRegistrationSecret = {
      directory: 'secrets',
      writeTo:   'complete-registration-secret.yaml',
      secret:     secretFile('complete-registration-secret', appEnv, [ 'COMPLETE_REGISTRATION_SECRET' ])
    };
    processed.secretFiles.mongoSecrets = {
      directory: 'secrets',
      writeTo:   'mongo-secrets.yaml',
      secret:     secretFile('mongo-secrets', appEnv, [ 'MONGO_URL', 'MONGO_OPLOG_URL', 'NUCLEUS_INGESTION_MONGO_URL' ])
    };
    processed.secretFiles.uxSecrets = {
      directory: 'secrets',
      writeTo:   'ux-secrets.yaml',
      secret:     secretFile('ux-secrets', appEnv, [ 'MAIL_URL', 'CAPTCHA_SITE_KEY', 'CAPTCHA_SECRET_KEY' ])
    };
    processed.secretFiles.meteorUiDdpSecret = {
      directory: 'secrets',
      writeTo:   'meteor-ui-ddp-secret.yaml',
      secret:     secretFile('meteor-ui-ddp-secret', appEnv, [ 'METEOR_SETTINGS' ])
    };
    processed.app[name] = 1;
    return;
  },

  p10Accumulator(name, appEnv) {
    generatePipelineConfig('p10Accumulator', name, appEnv);
  },

  p10Chunk(name, appEnv) {
    generatePipelineConfig('p10Chunk', name, appEnv);
  },

  studyRollup(name, appEnv) {
    generatePipelineConfig('studyRollup', name, appEnv);
  }
};

module.exports = {
  toCamelCase,
  generateConfigMap,
  generateSharedMapFile,
  processApplication,
  processed: processed
};
