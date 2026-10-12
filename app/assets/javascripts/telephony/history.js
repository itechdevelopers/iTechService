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
(function () {
  'use strict';
  function setupFilters() {
    var form = document.getElementById('call-history-filters');
    if (!form || form.getAttribute('data-ready') === '1') return;
    form.setAttribute('data-ready', '1');
    var fields = ['number', 'external_only', 'direction', 'status', 'department_id', 'employee_id', 'directory_id', 'group_name', 'date_from', 'date_to'];
    var key = 'ais/call-history/filters/' + form.getAttribute('data-employee');
    var status = document.getElementById('call-history-saved');
    var query = new URLSearchParams(window.location.search);
    try {
      var stored = JSON.parse(localStorage.getItem(key) || 'null');
      if (stored && !fields.some(function (field) { return query.has(field); }) && !query.has('defaults')) {
        var saved = new URLSearchParams();
        fields.forEach(function (field) { if (stored[field]) saved.set(field, stored[field]); });
        saved.set('defaults', '1');
        window.location.replace(window.location.pathname + '?' + saved.toString());
        return;
      }
    } catch (error) { /* Storage may be unavailable; ordinary filters still work. */ }
    form.elements.external_only.onchange = function () {
      if (this.checked && form.elements.direction.value === 'internal') form.elements.direction.value = '';
    };
    form.elements.direction.onchange = function () {
      if (this.value === 'internal') form.elements.external_only.checked = false;
    };
    document.getElementById('call-history-save').onclick = function () {
      var values = {};
      fields.forEach(function (field) {
        var input = form.elements[field];
        if (!input) return;
        values[field] = input.type === 'checkbox' ? (input.checked ? input.value : '') : input.value;
      });
      try {
        localStorage.setItem(key, JSON.stringify(values));
        status.textContent = 'Фильтры запомнены для этого пользователя в этом браузере.';
        form.submit();
      } catch (error) { status.textContent = 'Браузер не разрешил сохранить фильтры.'; }
    };
    document.getElementById('call-history-forget').onclick = function () {
      try { localStorage.removeItem(key); status.textContent = 'Сохранённые фильтры удалены.'; }
      catch (error) { status.textContent = 'Браузер не разрешил удалить настройки.'; }
    };
  }
  document.addEventListener('turbolinks:before-cache', function () {
    var form = document.getElementById('call-history-filters');
    if (form) form.removeAttribute('data-ready');
  });
  document.addEventListener('turbolinks:load', setupFilters);
  setupFilters();
})();
