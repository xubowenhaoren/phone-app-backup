'use strict';

angular.module('emission.main.aware', [
  'emission.plugin.logger',
  'ng-walkthrough',
  'nzTour',
  'angularLocalStorage',
  'emission.services'
]).
  controller('AwareCtrl',
    function ($scope, $state, $ionicPopup, nzTour, $ionicPopover, storage,
              CommHelper, $sce, $cordovaInAppBrowser) {
    //   // Tour steps
    //   var tour = {
    //     config: {
    //       mask: {
    //         visibleOnNoTarget: true,
    //         clickExit: true,
    //       },
    //     },
    //     steps: [
    //       {
    //         target: '#open-accessmap-button',
    //         content: 'Click the button to start AccessMap Emission edition and plan your route',
    //       },
    //       {
    //         target: '#open-accessmap-button',
    //         content: 'This will bring you outside the Emission app, but Emission will stay in the background to continue tracking',
    //       },
    //       {
    //         target: '#accessmap-help',
    //         content: 'Click here to read this tutorial again',
    //       },
    //     ],
    //   };

      // $scope.startWalkthrough = function () {
      //   nzTour.start(tour).then(function (result) {
      //     Logger.log('list walkthrough start completed, no error');
      //   }).catch(function (err) {
      //     Logger.log('list walkthrough start errored' + err);
      //   });
      // };

      /*
        * Checks if it is the first time the user has loaded the diary tab. If it is then
        * show a walkthrough and store the info that the user has seen the tutorial.
        */
      // var checkTutorialDone = function () {
      //   var ACCESSMAP_DONE_KEY = 'accessmap_tutorial_done';
      //   var accessmapTutorialDone = storage.get(ACCESSMAP_DONE_KEY);
      //   if (!accessmapTutorialDone) {
      //     $scope.startWalkthrough();
      //     storage.set(ACCESSMAP_DONE_KEY, true);
      //   }
      // };

      // var sliceUUID = function (uuidWithNoDash) {
      //   var uuidParts = [];
      //   uuidParts.push(uuidWithNoDash.slice(0,8));
      //   uuidParts.push(uuidWithNoDash.slice(8,12));
      //   uuidParts.push(uuidWithNoDash.slice(12,16));
      //   uuidParts.push(uuidWithNoDash.slice(16,20));
      //   uuidParts.push(uuidWithNoDash.slice(20,32));
      //   return uuidParts.join('-');
      // };

      $scope.pidPlaceholder = "pidPlaceholder";

      $scope.checkBattery = function () {
        // Load AccessMap with uuid
        // var url = $sce.trustAsResourceUrl('https://www.accessmap.io/signin');
        // $cordovaInAppBrowser.open(url, '_system', {
        //   location: 'no',
        //   clearcache: 'no',
        //   toolbar: 'yes'
        // });
        window.checkBattery(function(result) { alert(result); }, function(err) { alert(err); });
      };

      $scope.joinStudy = function (m_name) {

        window.joinStudy(m_name, function(result) { alert(result); }, function(err) { alert(err); });
      };

      $scope.manualSync = function () {

        window.manualSync(function(result) { alert(result); }, function(err) { alert(err); });
      };

      $scope.displayDeviceId = function () {

        window.displayDeviceId(function(result) { alert(result); }, function(err) { alert(err); });
      };

      $scope.$on('$ionicView.enter', function(ev) {
        // Workaround from
        // https://github.com/driftyco/ionic/issues/3433#issuecomment-195775629
        // if(ev.targetScope !== $scope) {
        //   return;
        // }
        window.displayPid(function(result) {$scope.pidPlaceholder = result;}, function(err) { alert(err); });

        // checkTutorialDone();
      });
    });