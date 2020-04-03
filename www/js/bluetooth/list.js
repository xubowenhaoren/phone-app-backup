'use strict';

angular
  .module( 'emission.main.bluetooth.list', [ ] )
  .controller( 'BluetoothListCtrl', function( $scope, $ionicPlatform, $ionicScrollDelegate ) {

    console.log( 'Controller BluetoothListCtrl called' )

    angular.extend( $scope, { defaults: { zoomControl: false, dragging: false, zoomAnimation: true, touchZoom: false, scrollWheelZoom: false, doubleClickZoom: false, boxZoom: false } } )

    var getContactEvents = _ => {
      $scope.data = []
      if ( contacttracing ) {
        contacttracing.startScanner( null, 10, ce => logContactEvent( ce, false ), e => console.error( 'SCAN', e ) )
        contacttracing.startAdvertiser( null, ce => logContactEvent( ce, true ), e => console.error( 'AD', e ) )
        $scope.update = setInterval( contacttracing.updateCEN, 60000 )
        $scope.refresh = _ => {
          if ($ionicScrollDelegate.getScrollPosition().top < 20) {
            clearInterval( $scope.update )
            contacttracing.stopScanner( scanStopped = e => {
              e && console.error( e )
              contacttracing.stopAdvertiser( adStopped = e => {
                e && console.error( e )
                getContactEvents()
              }, adStopped )
            }, adStopped )
          }
        }
      }
    }

    var logContactEvent = ( ce, ad ) => $scope.data.push( { time: new Date().toLocaleTimeString(), number: ce.cen.toUpperCase(), ad } )

    $ionicPlatform.ready().then( getContactEvents )

})
