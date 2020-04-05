'use strict';

angular
  .module( 'emission.main.bluetooth.list', [ 'emission.plugin.logger' ] )
  .controller( 'BluetoothListCtrl', function( $scope, $window, $ionicPlatform,
        $ionicScrollDelegate, Logger ) {

    console.log( 'Controller BluetoothListCtrl called' )

    angular.extend( $scope,
        { defaults: { zoomControl: false, dragging: false,
            zoomAnimation: true, touchZoom: false, scrollWheelZoom: false,
            doubleClickZoom: false, boxZoom: false } } );

    var startScanningContactEvents = _ => {
        $scope.data = [];
        var startScanPromise =
            $window.contacttracing.startScanner( null, 10)
            .then(ce => logContactEvent( ce, false ))
            .catch(e => console.error( 'SCAN', e ));
        var startAdvPromise =
          $window.contacttracing.startAdvertiser( null )
            .then( ce => logContactEvent( ce, true ))
            .catch( e => console.error( 'AD', e ));

        return Promise.all([startScanPromise, startAdvPromise]) .then(_ => {
          Logger.log("successfully started scanning, launching CEN update");
          $scope.update = $window.setInterval( $window.contacttracing.updateCEN,
            60000 );
        });
    }

    var stopScanningContactEvents = _ => {
        var stopScanPromise = $window.contacttracing.stopScanner();
        var stopAdvPromise = $window.contacttracing.stopAdvertiser();
        return Promise.all([stopScanPromise, stopAdvPromise]).then(_ => {
            Logger.log("successfully stopped scanning");
            console.log("About to clear interval" + $scope.update);
        }).catch(err => {
            Logger.displayError("stopping scan errored", err);
            console.log("About to clear interval" + $scope.update);
        });
    }

    $scope.refresh = _ => {
      if ($ionicScrollDelegate.getScrollPosition().top < 20) {
        stopScanningContactEvents().then(startScanningContactEvents());
      }
    }

    var logContactEvent = ( ce, ad ) => $scope.data.push(
        { time: new Date().toLocaleTimeString(), number: ce.cen.toUpperCase(), ad }
    );

    // $ionicPlatform.ready().then( startScanningContactEvents() );
});
