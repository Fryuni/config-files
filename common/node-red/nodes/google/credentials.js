"use strict";

module.exports = function (RED) {
  const { GoogleAuth } = require('google-auth-library');

  function GoogleCloudCredentialsNode(config) {
    RED.nodes.createNode(this, config);
    this.name = config.name;

    const account = this.credentials.account?.trim();
    if (account) {
      this.serviceAccount = JSON.parse(this.credentials.account);
      this.projectId = config.projectId || serviceAccount.project_id;
      this.auth = new GoogleAuth().fromJSON(this.serviceAccount);
      this.auth.projectId = this.projectId;
    } else {
      this.auth = new GoogleAuth({
        keyFilename: process.env.GOOGLE_APPLICATION_CREDENTIALS,
        projectId: config.projectId,
      });
    }
  }

  RED.nodes.registerType("google-cloud-credentials", GoogleCloudCredentialsNode, {
    credentials: {
      name: {
        type: "text",
        required: true
      },
      account: {
        type: "password",
        required: false
      }
    }
  });
};
