/**
 * Copyright JS Foundation and other contributors, http://js.foundation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

module.exports = function (RED) {
  "use strict";
  var exec = require('child_process').exec;
  var fs = require('fs');
  var isUtf8 = require('is-utf8');

  function ExecNode(n) {
    RED.nodes.createNode(this, n);
    this.cmd = (n.command || "").trim();
    this.timer = Number(n.timer || 0) * 1000;
    this.activeProcesses = {};
    this.oldrc = (n.oldrc || false).toString();
    this.execOpt = { encoding: 'utf8', maxBuffer: RED.settings.execMaxBufferSize || 10000000, windowsHide: (n.winHide === true) };
    var node = this;

    if (process.platform === 'linux' && fs.existsSync('/bin/bash')) { node.execOpt.shell = '/bin/bash'; }

    var cleanup = function (p) {
      node.activeProcesses[p].kill();
    }

    this.on("input", function (msg, nodeSend, nodeDone) {
      var child;
      // make the extra args into an array
      // then prepend with the msg.payload
      var arg = 'gcloud --format=json ' + node.cmd;
      if (node.addpay) {
        var value = RED.util.getMessageProperty(msg, node.addpay);
        if (value !== undefined) {
          arg += " " + value;
        }
      }
      if (node.append.trim() !== "") { arg += " " + node.append; }

      node.debug(arg);
      child = exec(arg, node.execOpt, function (error, stdout, stderr) {
        var msg2, msg3;
        delete msg.payload;
        if (stderr) {
          msg2 = RED.util.cloneMessage(msg);
          msg2.payload = stderr;
        }
        msg.payload = Buffer.from(stdout, "binary");
        if (isUtf8(msg.payload)) { msg.payload = msg.payload.toString(); }
        node.status({});

        if (error !== null) {
          msg3 = RED.util.cloneMessage(msg);
          msg3.payload = { code: error.code, message: error.message };
          if (error.signal) { msg3.payload.signal = error.signal; }
          if (error.code === null) { node.status({ fill: "red", shape: "dot", text: "killed" }); }
          else { node.status({ fill: "red", shape: "dot", text: "error:" + error.code }); }
          node.debug('error:' + error);
        }
        else if (node.oldrc === "false") {
          msg3 = RED.util.cloneMessage(msg);
          msg3.payload = { code: 0 };
        }
        if (!msg3) { node.status({}); }
        else {
          msg.rc = msg3.payload;
          if (msg2) { msg2.rc = msg3.payload; }
        }
        nodeSend([msg, msg2, msg3]);
        if (child.tout) { clearTimeout(child.tout); }
        delete node.activeProcesses[child.pid];
        nodeDone();
      });
      node.status({ fill: "blue", shape: "dot", text: "pid:" + child.pid });
      child.on('error', function () { });
      if (node.timer !== 0) {
        child.tout = setTimeout(function () { cleanup(child.pid); }, node.timer);
      }
      node.activeProcesses[child.pid] = child;
    });

    this.on('close', function () {
      for (var pid in node.activeProcesses) {
        /* istanbul ignore else  */
        if (node.activeProcesses.hasOwnProperty(pid)) {
          if (node.activeProcesses[pid].tout) { clearTimeout(node.activeProcesses[pid].tout); }
          const child = node.activeProcesses[pid];
          node.activeProcesses[pid] = null;
          child.kill();
        }
      }
      node.activeProcesses = {};
      node.status({});
    });
  }
  RED.nodes.registerType("gcloud", ExecNode);
}
