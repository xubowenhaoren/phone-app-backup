'use strict';

angular
  .module( 'emission.main.bluetooth.list', [ ] )
  .controller( 'BluetoothListCtrl', function( $window, $scope, $rootScope, $ionicPlatform, $ionicScrollDelegate, 
                                              $ionicPopup, ionicDatePicker, Timeline, CommonGraph, DiaryHelper, 
                                              PostTripManualMarker, ConfirmHelper,  Logger, $translate ) {

    console.log( 'Controller BluetoothListCtrl called' )

    angular.extend( $scope, { 
      defaults: { 
        zoomControl: false, dragging: false, zoomAnimation: true, touchZoom: false, scrollWheelZoom: false, doubleClickZoom: false, boxZoom: false 
      } 
    } )

    $scope.refresh = _ => {
      if ($ionicScrollDelegate.getScrollPosition().top < 20) {
        $scope.$broadcast('invalidateSize')
      }
    }

    $scope.$on( '$ionicView.loaded', _ => { } )

    $ionicPlatform.ready().then( _ => {

      // load data here
      // contacttracing.startAdvertiser()
      // contacttracing.startScanner()

      $scope.data = [ { time: new Date().toLocaleTimeString(), number: '01234567-89AB-CDEF-01234-567890ABCDEF', ad:false }, { time: new Date().toLocaleTimeString(), number: '01234567-89AB-CDEF-01234-567890ABCDEF', ad:true } ]

      $scope.$on( '$ionicView.afterEnter', _ => {  } )

    } )

})
