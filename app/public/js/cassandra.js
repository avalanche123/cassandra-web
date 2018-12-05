// From https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/keys
if (!Object.keys) {
  Object.keys = (function () {
    'use strict';
    var hasOwnProperty = Object.prototype.hasOwnProperty,
        hasDontEnumBug = !({toString: null}).propertyIsEnumerable('toString'),
        dontEnums = [
          'toString',
          'toLocaleString',
          'valueOf',
          'hasOwnProperty',
          'isPrototypeOf',
          'propertyIsEnumerable',
          'constructor'
        ],
        dontEnumsLength = dontEnums.length;

    return function (obj) {
      if (typeof obj !== 'object' && (typeof obj !== 'function' || obj === null)) {
        throw new TypeError('Object.keys called on non-object');
      }

      var result = [], prop, i;

      for (prop in obj) {
        if (hasOwnProperty.call(obj, prop)) {
          result.push(prop);
        }
      }

      if (hasDontEnumBug) {
        for (i = 0; i < dontEnumsLength; i++) {
          if (hasOwnProperty.call(obj, dontEnums[i])) {
            result.push(dontEnums[i]);
          }
        }
      }
      return result;
    };
  }());
}

!(function(app) {
  app.config([
    '$routeProvider',
    '$locationProvider',
    '$rootScopeProvider',
    '$logProvider',
    '$compileProvider',
    function($routeProvider, $locationProvider, $rootScopeProvider, $logProvider, $compileProvider) {
      $routeProvider
        .when('/', {
          templateUrl: '/html/index.html',
        })
        .when('/:keyspace', {
          templateUrl: '/html/keyspace.html',
          controller: 'keyspace',
          resolve: {cluster: 'cluster'}
        })
        .when('/:keyspace/:table', {
          templateUrl: '/html/table.html',
          controller: 'table',
          resolve: {cluster: 'cluster'}
        })
        .otherwise({redirect:'/'})

      $locationProvider.html5Mode(true)
      $rootScopeProvider.digestTtl(10000)
      $logProvider.debugEnabled(true)
      $compileProvider.debugInfoEnabled(true)
    }
  ])

  app.factory('cluster', [
    '$http',
    '$rootScope',
    '$q',
    function($http, $rootScope, $q) {
      var cluster = {
        keyspaces: null,
        hosts: null,
        keyspace: null,
        execute: function(statement, options) {
          var deferred = $q.defer();
          options = options || {}

          $http({
            method: 'POST',
            url: '/execute',
            data: {
              statement: statement,
              options: options
            }
          })
            .success(function(data, status, headers, config) {
              deferred.resolve(data)
            })
            .error(function(data, status, headers, config) {
              deferred.reject(data)
            })

          return deferred.promise
        }
      }
      var resolved = false
      var deferred = $q.defer()

      var events = new EventSource('/events');

      events.onopen = function(e) {
        updateCluster();
        return false;
      }

      $rootScope.$on('$destroy', function() {
        events.close();
      })

      var updateCluster = function() {
        $http({method: 'GET', url: '/keyspaces'})
          .success(function(data, status, headers, config) {
            cluster.keyspaces = data

            events.addEventListener('keyspace_created', addKeyspace, false);
            events.addEventListener('keyspace_changed', updateKeyspace, false);
            events.addEventListener('keyspace_dropped', removeKeyspace, false);

            if (!resolved && cluster.keyspaces && cluster.hosts) {
              resolved = true
              deferred.resolve(cluster)
            }
          })
          .error(function(data, status, headers, config) {
            console.log('ERROR', data);
          })

        $http({method: 'GET', url: '/hosts'})
          .success(function(data, status, headers, config) {
            cluster.hosts = data

            events.addEventListener('host_found', addHost, false);
            events.addEventListener('host_up',    updateHost, false);
            events.addEventListener('host_down',  updateHost, false);
            events.addEventListener('host_lost',  removeHost, false);

            if (!resolved && cluster.keyspaces && cluster.hosts) {
              resolved = true
              deferred.resolve(cluster)
            }
          })
          .error(function(data, status, headers, config) {
            console.log('ERROR', data);
          })
      }

      var addHost = function(event) {
        var host = JSON.parse(event.data)

        $rootScope.$apply(function() {
          $rootScope.$broadcast('host.created', host)
          cluster.hosts.push(host)
        })
      }

      var updateHost = function(event) {
        var host = JSON.parse(event.data)

        $rootScope.$apply(function() {
          $rootScope.$broadcast('host.updated', host)
          angular.forEach(cluster.hosts, function(h, index) {
            if (host.ip == h.ip) {
              angular.forEach(host, function(value, key) {
                cluster.hosts[index][key] = value
              })
            }
          })
        })
      }

      var removeHost = function(event) {
        var host = JSON.parse(event.data)

        $rootScope.$apply(function() {
          $rootScope.$broadcast('host.removed', host)
          angular.forEach(cluster.hosts, function(h, index) {
            if (host.ip == h.ip) {
              cluster.hosts.splice(index, 1)
            }
          })
        })
      }

      var addKeyspace = function(event) {
        var keyspace = JSON.parse(event.data)

        $rootScope.$apply(function() {
          $rootScope.$broadcast('keyspace.created', keyspace)
          cluster.keyspaces.push(keyspace)
        })
      }

      var updateKeyspace = function(event) {
        var keyspace = JSON.parse(event.data)

        $rootScope.$apply(function() {
          $rootScope.$broadcast('keyspace.updated', keyspace)
          angular.forEach(cluster.keyspaces, function(k, index) {
            if (keyspace.name == k.name) {
              angular.forEach(keyspace, function(value, key) {
                cluster.keyspaces[index][key] = value
              })
            }
          })
        })
      }

      var removeKeyspace = function(event) {
        var keyspace = JSON.parse(event.data)

        $rootScope.$apply(function() {
          $rootScope.$broadcast('keyspace.removed', keyspace)
          angular.forEach(cluster.keyspaces, function(k, index) {
            if (keyspace.name == k.name) {
              cluster.keyspaces.splice(index, 1)
            }
          })
        })
      }

      return deferred.promise
    }
  ])

  app.factory('escapeIdentifier', [
    function() {
      var re = /[a-z][a-z0-9_]*/

      return function(id) {
        var matches = id.match(re)
        if (matches.length == 1 && matches[0].length == id.length) {
          return id
        }
        return '"' + id + '"'
      }
    }
  ])

  app.directive('codeHighlight',[
    '$interpolate',
    '$compile',
    function ($interpolate, $compile) {
      return {
        restrict: 'E',
        template: '<code ng-transclude></code>',
        replace: true,
        transclude: true,
        link: function (scope, el, attrs) {
          var language = Prism.languages[attrs.language]

          attrs.$observe('code', function(code) {
            el.html(Prism.highlight(code, language))
          })
        }
      }
    }
  ])

  app.controller('main', [
    '$scope',
    'cluster',
    '$routeParams',
    '$modal',
    function($scope, cluster, $routeParams, $modal) {
      cluster.then(
        function(cluster) {
          $scope.cluster = cluster
        }
      )

      $scope.host_status_class = function(status) {
        if (status == 'up') {
          return 'success'
        }

        return 'danger'
      }

      $scope.keyspace_class = function(keyspace) {
        if ($routeParams.keyspace && $routeParams.keyspace == keyspace.name) {
          return 'active'
        }
      }

      $scope.show_execute_form = function(statement) {
        var childScope = $scope.$new()

        childScope.statement = {cql: statement}

        return $modal.open({
          templateUrl: '/html/execute.html',
          controller: 'execute',
          size: 'lg',
          scope: childScope
        })
      }
    }
  ])

  app.controller('execute', [
    '$scope',
    function($scope) {
      $scope.disabled = false
      $scope.options = $scope.options || {
        trace:       false,
        consistency: 'one'
      }
      $scope.statement = $scope.statement || {
        cql: ''
      }
      $scope.consistencies = [
        "any",
        "one",
        "two",
        "three",
        "quorum",
        "all",
        "local_quorum",
        "each_quorum",
        "serial",
        "local_serial",
        "local_one"
      ]

      $scope.execute = function() {
        $scope.disabled = true

        $scope.cluster.execute($scope.statement.cql, $scope.options)
          .then(
            function(result) {
              $scope.disabled = false
              $scope.result   = result;
            },
            function(error) {
              $scope.error = error
            }
          )
      }

      $scope.$watch('options.consistency', function(consistency) {
        if ($scope.error) {
          $scope.disabled = false
          delete $scope.error
        }
      })

      $scope.$watch('statement.cql', function(cql) {
        if ($scope.error) {
          $scope.disabled = false
          delete $scope.error
        }
      })
    }
  ])

  app.controller('keyspace', [
    '$scope',
    'cluster',
    '$routeParams',
    '$location',
    function($scope, cluster, $routeParams, $location) {
      cluster.keyspaces.forEach(function(keyspace) {
        if ($routeParams.keyspace == keyspace.name) {
          $scope.keyspace = keyspace
        }
      })

      if (!$scope.keyspace) {
        $location.path('/')
      }

      $scope.$on('keyspace.removed', function(event, keyspace) {
        if ($routeParams.keyspace == keyspace.name) {
          $location.path('/')
        }
      })
    }
  ])

  app.controller('table', [
    '$scope',
    'cluster',
    '$routeParams',
    '$location',
    'escapeIdentifier',
    function($scope, cluster, $routeParams, $location, escapeIdentifier) {

      $scope.rowLimit = {
        enabled: true,
        value: 15
      };
      $scope.loading = false;

      cluster.keyspaces.forEach(function(keyspace) {
        if ($routeParams.keyspace == keyspace.name) {
          $scope.keyspace = keyspace
        }
      })

      if (!$scope.keyspace) {
        $location.path('/')
      }

      $scope.$on('keyspace.removed', function(event, keyspace) {
        if ($routeParams.keyspace == keyspace.name) {
          $location.path('/')
        }
      })

      $scope.keyspace.tables.forEach(function(table) {
        if ($routeParams.table == table.name) {
          $scope.table = table
        }
      })

      if (!$scope.table) {
        $location.path('/')
      }

      $scope.$on('keyspace.updated', function(keyspace) {
        if ($routeParams.keyspace != keyspace.name) {
          return
        }

        var exists = false;

        keyspace.tables.forEach(function(table) {
          exists = exists || (table.name == $scope.table.name)
        })

        if (!exists) {
          $location.path('/' + $scope.keyspace.name)
        }
      });

      $scope.executeStatement = function() {
        $scope.result = undefined;
        $scope.loading = true;

        var selectStatement = 'SELECT * FROM ' + escapeIdentifier($scope.keyspace.name) + '.' + escapeIdentifier($scope.table.name);
        if ($scope.rowLimit.enabled) {
          selectStatement = selectStatement + ' LIMIT ' + $scope.rowLimit.value;
        }

        cluster.execute(selectStatement)
          .then(
            function(result) {
              $scope.result = result;
              $scope.loading = false;
            },
            function(error) {
              $scope.error = error;
              $scope.loading = false;
            }
          );
      };

      $scope.executeStatement();

    }
  ]);

  app.controller('actions', [
    '$scope',
    'cluster',
    'escapeIdentifier',
    function($scope, cluster, escapeIdentifier) {
      $scope.disabled = false
      $scope.drop = function(keyspaceName, tableName) {
        $scope.disabled = true

        return cluster
          .then(
            function(cluster) {
              return cluster
                .execute('DROP TABLE ' + escapeIdentifier($scope.keyspace.name) + '.' + escapeIdentifier(tableName))
            }
          )
          .then(
            function(result) {
              $scope.result = result
              $scope.disabled = false
            },
            function(error) {
              $scope.error = error
            }
          )
      }
    }
  ])
})(angular.module('cassandra', ['ngRoute', 'angular.filter', 'ui.bootstrap', 'ui.codemirror']))
