// Страница инстансов GREEN-API. Состояние каждого канала догружается
// отдельным запросом: GREEN-API отвечает секундами, и страница не должна их
// ждать. QR-код для входа живёт секунды, поэтому его запрашиваем снова, пока
// аккаунт не подключится, — но не бесконечно: забытая вкладка не должна
// дёргать GREEN-API часами.
var greenApiInstances = (function () {
  var QR_INTERVAL = 5000;
  var QR_TIMEOUT = 3 * 60 * 1000;

  function loadStatuses() {
    $('[data-green-api-status]').each(function () {
      $.getScript($(this).data('greenApiStatus'));
    });
  }

  function startQr(container) {
    var box = container.find('.green-api-instances__qr-box');
    var image = box.find('.green-api-instances__qr-image');
    var text = box.find('.green-api-instances__qr-text');
    var startedAt = Date.now();
    var timer = null;

    function finish(message) {
      clearInterval(timer);
      image.hide();
      text.text(message);
    }

    function poll() {
      if (Date.now() - startedAt > QR_TIMEOUT) {
        finish(container.data('greenApiQrExpired'));
        return;
      }
      $.ajax({ url: container.data('greenApiQr'), dataType: 'json', cache: false })
        .done(function (data) {
          if (data.status === 'qr') {
            image.attr('src', data.image).show();
            text.text(container.data('greenApiQrHint'));
          } else if (data.status === 'authorized') {
            finish(data.text);
            setTimeout(function () { window.location.reload(); }, 2000);
          } else if (data.status === 'passkey') {
            finish(data.text);
          } else {
            text.text(data.text);
          }
        })
        .fail(function () { text.text(container.data('greenApiQrFailed')); });
    }

    box.show();
    poll();
    timer = setInterval(poll, QR_INTERVAL);
  }

  $(document).on('click', '[data-green-api-qr-start]', function (event) {
    event.preventDefault();
    $(this).hide();
    startQr($(this).closest('[data-green-api-qr]'));
  });

  $(loadStatuses);

  return { loadStatuses: loadStatuses };
})();
