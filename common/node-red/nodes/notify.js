'use strict';

const { inputHandler } = require('./utils.js');

module.exports = function (RED) {
  const { execFile } = require('node:child_process');

  function NotifyNode(n) {
    RED.nodes.createNode(this, n);
    const node = this;
    node.name = n.name;
    node.appName = {
      target: n.appName,
      type: n.appNameType,
    };
    node.message = {
      target: n.message,
      type: n.messageType,
    };

    inputHandler(node, async msg => {
      const appName = RED.util.evaluateNodeProperty(node.appName.target, node.appName.type, node, msg);
      let message = RED.util.evaluateNodeProperty(node.message.target, node.message.type, node, msg);
      if (typeof message !== 'string') {
        message = JSON.stringify(message, null, 2);
      }

      node.warn({ appName, message });

      const execOptions = {};
      const args = [
        '-a', appName,
        '-e', '-t', '3500',
        message,
      ];

      return new Promise((resolve, reject) => {
        execFile('notify-send', args, execOptions, (error) => {
          if (error) {
            reject(error);
          } else {
            resolve();
          }
        });
      });
    });
  }

  RED.nodes.registerType('notify', NotifyNode);
};
