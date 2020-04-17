angular
  .module( 'emission.main.bluetooth', [ 'emission.main.bluetooth.list' /*, 'emission.main.bluetooth.services' */ ] )
  .config( function ( $stateProvider ) {
    $stateProvider
      .state( 'root.main.bluetooth', {
        url : '/bluetooth',
        views : {
          'main-bluetooth' : {
            templateUrl : 'templates/bluetooth/list.html',
            controller : 'BluetoothListCtrl'
          }
        }
      } )
  } )
