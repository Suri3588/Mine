const chai = require('chai');
const sinonChai = require('sinon-chai');
const k8s = require('../../cmds/k8s-main');
const expect = chai.expect;
chai.use(sinonChai);

describe('k8s', function() {
  beforeEach(function() {
    this.appEnv = {
      "NUCLEUS_LOG_INFO":  "*",
      'NUCLEUS_SERVICE_ROLE': "ddp",
      'ROOT_URL': "https://nk8s_tempalte.nucleusdev.io"
    };
    this.port = 3000;
  });
  it('generateConfigMap', function() {
    const results = k8s.generateConfigMap('meteor-ui-ddp', this.appEnv, this.port);
    expect(results.configMap.data).to.have.property('NUCLEUS_LOG_INFO');
    expect(results.configMap.data['NUCLEUS_LOG_INFO']).equal(this.appEnv['NUCLEUS_LOG_INFO']);
    expect(results.configMap.data).to.have.property('NUCLEUS_SERVICE_ROLE');
    expect(results.configMap.data['NUCLEUS_SERVICE_ROLE']).equal(this.appEnv['NUCLEUS_SERVICE_ROLE']);
    expect(results.configMap.data).to.have.property('PORT');
    expect(results.configMap.data['PORT']).equal(this.port);
  });
  it('generateSharedMapFile', function() {
    const ROOT_URL = this.appEnv['ROOT_URL'].replace('_', '-');
    const results = k8s.generateSharedMapFile(this.appEnv);
    expect(results.configMap.data).to.have.property('ROOT_URL');
    expect(results.configMap.data['ROOT_URL']).equal(ROOT_URL);
  });
  it('generateConfigMap with extra arg, root_url', function() {
    const extra = {
      root_url: this.appEnv.ROOT_URL.replace('_', '-') + "/ndx"
    };
    const results = k8s.generateConfigMap('image-data-service', this.appEnv, 3000, extra);
    expect(results.configMap.data).to.have.property('ROOT_URL');
    expect(results.configMap.data['ROOT_URL']).equal(extra.root_url);
  });
});
