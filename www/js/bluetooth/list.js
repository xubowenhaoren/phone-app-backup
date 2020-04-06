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

    $scope.startAdvertiser = _ => {
        $window.cordova.plugins.contacttracing.startAdvertiser( null )
            .catch(err => Logger.displayError("Error while starting advertise", err));
    }

    $scope.stopAdvertiser = _ => {
        $window.cordova.plugins.contacttracing.stopAdvertiser()
            .catch(err => Logger.displayError("Error while stopping advertise", err));
    }

    $scope.startScan = _ => {
        $window.cordova.plugins.contacttracing.startScanner( null, 10 )
            .catch(err => Logger.displayError("Error while starting scan", err));
    }

    $scope.stopScan = _ => {
        $window.cordova.plugins.contacttracing.stopScanner()
            .catch(err => Logger.displayError("Error while stopping scan", err));
    }

    $scope.pullRefresh = _ => {
      if ($ionicScrollDelegate.getScrollPosition().top < 20) {
        $scope.refresh();
        return true;
      }
    }

    $scope.formatTime = (ts_in_secs) => moment(ts_in_secs * 1000).format('LT')

    $scope.refresh = _ => {
        console.log("About to refresh CEN list");
        $window.cordova.plugins.contacttracing.updateCEN().then(cenList => {
            Logger.log("Retrieved list of size "+cenList.length);
            $scope.$apply(_ => {
                $scope.data = cenList.map(cen => {
                    if(cen.type == "advertise") {
                        cen.ad = true;
                    } else {
                        cen.ad = false;
                    }
                    return cen;
                });;
            });
        }).catch(err => Logger.displayError("Error refreshing", err));
    }

    var logContactEvent = ( ce, ad ) => $scope.data.push(
        { time: new Date().toLocaleTimeString(), number: ce.cen.toUpperCase(), ad }
    );

    $ionicPlatform.ready().then( $scope.update = $window.setInterval(
        $scope.refresh(), 60000 ) );

    $ionicPlatform.ready().then( $scope.testPeriodic = $window.setInterval(
        console.log("Periodic call"), 60000 ) );
});
