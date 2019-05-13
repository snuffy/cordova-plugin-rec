'use strict';

var exec = require('cordova/exec');

// cordova exec
var _Rec = {
  start: (onSuccess, onFail, param) => {
    return exec(onSuccess, onFail, 'Rec', 'start', [param]);
  },
  pause: (onSuccess, onFail, param) => {
    return exec(onSuccess, onFail, 'Rec', 'pause', [param]);
  },
  resume: (onSuccess, onFail, param) => {
    return exec(onSuccess, onFail, 'Rec', 'stop', [param]);
  },
  stop: (onSuccess, onFail, param) => {
    return exec(onSuccess, onFail, 'Rec', 'stop', [param]);
  },
};

// promise wrapper
var Rec = {
  start: (params) => {
    return new Promise((resolve, reject) => {
      _Rec.start((res) => {
        resolve(res);
      }, (err) => {
        reject(err);
      }, params);
    });
  },
  pause: (params) => {
    return new Promise((resolve, reject) => {
      _Rec.pause((res) => {
        resolve(res);
      }, (err) => {
        reject(err);
      }, params);
    });
  },
  resume: (params) => {
    return new Promise((resolve, reject) => {
      _Rec.pause((res) => {
        resolve(res);
      }, (err) => {
        reject(err);
      }, params);
    });
  },
  stop: (params) => {
    return new Promise((resolve, reject) => {
      _Rec.stop((res) => {
        resolve(res);
      }, (err) => {
        reject(err);
      }, params);
    });
  },
}

module.exports = Rec;
