module.exports = {

  startScanner : ( uuid, delay ) => { 
    return new Promise(function(resolve, reject) {
        cordova.exec( resolve, reject, 'ContactTracing', 'startScanner', [ uuid, delay ] ) 
    });
  },

  stopScanner : ( ) => { 
    return new Promise(function(resolve, reject) {
        cordova.exec( resolve, reject, 'ContactTracing', 'stopScanner', [ ] ) 
    });
  },

  startAdvertiser : ( uuid ) => { 
    return new Promise(function(resolve, reject) {
        cordova.exec( resolve, reject, 'ContactTracing', 'startAdvertiser', [ uuid ] ) 
    });
  },

  stopAdvertiser : ( ) => { 
    return new Promise(function(resolve, reject) {
        cordova.exec( resolve, reject, 'ContactTracing', 'stopAdvertiser', [ ] ) 
    });
  },

  updateCEN : ( ) => { 
    return new Promise(function(resolve, reject) {
        cordova.exec( resolve, reject, 'ContactTracing', 'updateCEN', [ ] ) 
    });
  }

}
