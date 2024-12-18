'use strict';

const noop = () => { };

module.exports = {
  inputHandler: (node, handler) => {
    node.on('input', async (msg, send = node.send.bind(node), done = noop) => {
      try {
        await handler(msg, send);
      } catch (err) {
        done(err);
      }
    });
  },
};
