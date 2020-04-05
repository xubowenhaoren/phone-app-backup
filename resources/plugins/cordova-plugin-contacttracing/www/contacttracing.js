module.exports = {

  startScanner : ( uuid, delay, success, error ) => { 
    cordova.exec( success, error, 'ContactTracing', 'startScanner', [ uuid, delay ] ) 
  },

  stopScanner : ( success, error ) => { 
    cordova.exec( success, error, 'ContactTracing', 'stopScanner', [ ] ) 
  },

  startAdvertiser : ( uuid, success, error ) => { 
    cordova.exec( success, error, 'ContactTracing', 'startAdvertiser', [ uuid ] ) 
  },

  stopAdvertiser : ( success, error ) => { 
    cordova.exec( success, error, 'ContactTracing', 'stopAdvertiser', [ ] ) 
  },

  updateCEN : ( success, error ) => { 
    cordova.exec( success, error, 'ContactTracing', 'updateCEN', [ ] ) 
  }

}
