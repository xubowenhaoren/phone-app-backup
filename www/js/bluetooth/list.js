'use strict';

angular.module( 'emission.main.bluetooth.list', [ 'emission.plugin.logger' ] )
    .controller( 'BluetoothListCtrl', function( $scope, $window, $ionicScrollDelegate, Logger ) {

    console.log( 'Controller BluetoothListCtrl called' )

    angular.extend( $scope,
        { defaults: { zoomControl: false, dragging: false, zoomAnimation: true, touchZoom: false, 
            scrollWheelZoom: false, doubleClickZoom: false, boxZoom: false } } )

    $scope.start = _ => {
        $window.cordova.plugins.contacttracing.start()
            .then( _ => { $scope.update = $window.setInterval( $scope.refresh, 10000 ) } )
            .catch( e => Logger.displayError( 'Error while starting BLE Contact Tracing' , e ) )
    }

    $scope.stop = _ => {
        $window.cordova.plugins.contacttracing.stop()
            .then( _ => $window.clearInterval( $scope.update ) )
            .catch( e => Logger.displayError( 'Error while stopping BLE Contact Tracing' , e ) )
    }

    $scope.pullRefresh = _ => {
        if ( $ionicScrollDelegate.getScrollPosition().top < 20 ) {
            $scope.refresh()
            return true
        }
    }

    $scope.formatTime = ts => moment( ts ).format( 'LT' )

    $scope.refresh = _ => {
        console.log( 'About to refresh CEN list' )
        $window.cordova.plugins.contacttracing.getCENs().then( cenList => {
            Logger.log( 'Retrieved list of size ' + cenList.length )
            $scope.$apply( _ => { $scope.data = cenList } )
        } ).catch( e => Logger.displayError( 'Error refreshing', e ) )
    }

} )
