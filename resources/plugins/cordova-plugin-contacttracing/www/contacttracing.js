module.exports = {

  start : ( ) =>  new Promise( ( resolve, reject ) => {
    cordova.exec( resolve, reject, 'ContactTracing', 'start', [ ] ) 
  } ),

  stop : ( ) =>  new Promise( ( resolve, reject ) => {
    cordova.exec( resolve, reject, 'ContactTracing', 'stop', [ ] ) 
  } ),

  getCENs : ( ) =>  new Promise( ( resolve, reject ) => {
    cordova.exec( resolve, reject, 'ContactTracing', 'getCENs', [ ] ) 
  } )

}
