(function () {
  'use strict';
  function initialize() {
    if (window.stopAISCallHistory) window.stopAISCallHistory();
    var element = document.getElementById('call-history-live');
    if (!element) return;
    var warning = document.getElementById('call-history-warning');
    var timer, request, stopped = false;
    function failed() {
      if (!stopped && warning) warning.textContent = 'Обновление недоступно. Данные могут быть устаревшими.';
    }
    function refresh() {
      if (stopped) return;
      if (document.hidden) { timer = setTimeout(refresh, 2000); return; }
      request = new XMLHttpRequest();
      request.open('GET', element.getAttribute('data-refresh-url'), true);
      request.timeout = 10000;
      request.setRequestHeader('X-Requested-With', 'XMLHttpRequest');
      request.onload = function () {
        if (stopped) return;
        if (request.status === 200 && request.responseText.indexOf('<table') !== -1) {
          var open = Array.prototype.map.call(element.querySelectorAll('details[open]'), function (node) {
            return node.getAttribute('data-call-id');
          });
          element.innerHTML = request.responseText;
          Array.prototype.forEach.call(element.querySelectorAll('details'), function (node) {
            if (open.indexOf(node.getAttribute('data-call-id')) !== -1) node.open = true;
          });
          if (warning) warning.textContent = '';
        } else failed();
      };
      request.onerror = failed;
      request.ontimeout = failed;
      request.onloadend = function () { if (!stopped) timer = setTimeout(refresh, 2000); };
      request.send();
    }
    window.stopAISCallHistory = function () {
      stopped = true;
      clearTimeout(timer);
      if (request) request.abort();
    };
    timer = setTimeout(refresh, 2000);
  }
  if (!window.aisCallHistoryInitialized) {
    window.aisCallHistoryInitialized = true;
    document.addEventListener('turbolinks:load', initialize);
    document.addEventListener('turbolinks:before-cache', function () {
      if (window.stopAISCallHistory) window.stopAISCallHistory();
    });
    window.addEventListener('pagehide', function () {
      if (window.stopAISCallHistory) window.stopAISCallHistory();
    });
  }
  initialize();
})();
