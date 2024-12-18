'use strict';

const { inputHandler } = require('./utils.js');

module.exports = function (RED) {
  const { Pool } = require('pg');

  function pgConfigNode(n) {
    const node = this;
    RED.nodes.createNode(node, n);

    this.pgPool = new Pool({
      user: this.credentials.user,
      password: this.credentials.password,
      host: n.host,
      port: n.port,
      database: n.dbname,
      max: n.max,
      idleTimeoutMillis: n.idleTimeout,
      connectionTimeoutMillis: n.connectionTimeoutMillis,
    });

    this.pgPool.on('error', (err, _) => {
      node.error(err.message);
    });

    this.on('close', () => {
      this.pgPool.end();
    });
  }

  RED.nodes.registerType('pgConfig', pgConfigNode, {
    credentials: {
      user: { type: "text" },
      password: { type: "password" },
    },
  });

  function pgGoogleConfigNode(n) {
    const node = this;
    RED.nodes.createNode(node, n);
    const credentialsNode = RED.nodes.getNode(n.account);

    const { Connector } = require('@google-cloud/cloud-sql-connector');

    try {
      const connector = new Connector(
        !!credentialsNode.serviceAccount
          ? { auth: credentialsNode.auth }
          : {},
      );

      this.pgPool = connector.getOptions({
        instanceConnectionName: n.instance,
        ipType: 'PUBLIC',
      }).then(clientOpts => {
        const pgPool = new Pool({
          ...clientOpts,
          user: this.credentials.user,
          password: this.credentials.password,
          database: n.dbname,
          max: n.max,
          idleTimeoutMillis: n.idleTimeout,
          connectionTimeoutMillis: n.connectionTimeoutMillis,
        });

        pgPool.on('error', (err, _) => {
          node.error(err.message);
        });

        this.on('close', () => {
          this.pgPool.end();
        });

        return pgPool
      })
        .catch(err => {
          console.error(err);
          node.error(err);
        });

    } catch (err) {
      console.error(err);
      node.error(err);
      return;
    }
  }

  RED.nodes.registerType('pgGoogleConfig', pgGoogleConfigNode, {
    credentials: {
      user: { type: "text" },
      password: { type: "password" },
    },
  });

  function getConfigId({ serverKind, pgConfig, pgGoogleConfig }) {
    switch (serverKind) {
      case 'direct':
        return pgConfig;
      case 'google':
        return pgGoogleConfig;
      default:
        throw new Error('Invalid server kind: ' + serverKind);
    }
  }

  function pgSQLNode(config) {
    const node = this;
    RED.nodes.createNode(node, config);
    node.pgConfig = RED.nodes.getNode(getConfigId(config));
    node.query = config.query
    node.name = config.name
    node.outputFormat = config.outputFormat

    const check_db = async function () {
      let client
      try {
        const pool = node.pgConfig.pgPool
        client = await pool.connect()
        await client.query("select 1")
        node.status({ fill: "green", shape: "ring", text: RED._('pg.conn.connect') });
      } catch (e) {
        node.status({ fill: "red", shape: "ring", text: RED._('pg.conn.disconnect') });
      } finally {
        client && client.release()
      }
    }
    check_db()

    inputHandler(node, async (msg, send) => {
      const handleError = function (err) {
        send([null, { ...msg, payload: err }])
        throw err;
      }

      const pool = await node.pgConfig.pgPool;
      if (!pool) {
        return handleError(RED._("pg.error.no_config"))
      }
      let query = node.query || msg.query
      if (!query) {
        return handleError(RED._("pg.error.no_query"))
      }
      let queryParams = msg.queryParams
      delete msg.query
      delete msg.queryParams
      let searchQuery = {
        text: query,
        values: queryParams,
        rowMode: 'array',
      }
      let client;
      try {
        const handle_data = function (res, output) {
          let keys = res.fields
          let rows = res.rows
          for (let i = 0; i < rows.length; i++) {
            let obj = {}
            for (let j = 0; j < keys.length; j++) {
              let name = keys[j].name
              obj[name] = rows[i][j]
            }
            output.push(obj)
          }
        }

        client = await pool.connect()
        let ress = await client.query(searchQuery)
        // node.log(JSON.stringify(ress))
        let output = []
        if (Array.isArray(ress)) {
          for (let i = 0; i < ress.length; i++) {
            let res = ress[i]
            handle_data(res, output)
          }
        } else {
          handle_data(ress, output)
        }
        if ('mul' !== node.outputFormat && output.length <= 1) {
          msg.payload = output.length === 1 ? output[0] : null
        } else {
          msg.payload = output
        }

        send([msg, null])
      } catch (e) {
        handleError(`${e}${searchQuery && searchQuery.text ? ` | ` + searchQuery.text : ''}${searchQuery && searchQuery.values ? ` | ` + JSON.stringify(searchQuery.values) : ''}`)
      } finally {
        client && client.release()
      }
    });
  }

  RED.nodes.registerType('pg', pgSQLNode);
};
