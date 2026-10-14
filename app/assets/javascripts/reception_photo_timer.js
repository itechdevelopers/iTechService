// Таймер фото при приёмке в шапке работы (ServiceJobsHelper#reception_photo_timer).
// Сервер отдаёт начальное значение; тикаем только пока фото нет (нет data-photo-at).
$(function () {
  function formatPhotoTimer(seconds) {
    var days = Math.floor(seconds / 86400);
    var rest = seconds % 86400;
    var pad = function (n) { return (n < 10 ? '0' : '') + n; };
    var clock = Math.floor(rest / 3600) + ':' + pad(Math.floor(rest % 3600 / 60)) + ':' + pad(rest % 60);
    return days > 0 ? days + ' д ' + clock : clock;
  }

  $('.reception-photo-timer').each(function () {
    var $timer = $(this);
    if ($timer.attr('data-photo-at')) return;

    var startedAt = Date.parse($timer.attr('data-started-at'));
    var warnAfter = Number($timer.attr('data-warn-after'));
    var alertAfter = Number($timer.attr('data-alert-after'));
    var $value = $timer.find('.reception-photo-timer__value');

    setInterval(function () {
      var seconds = Math.max(0, Math.floor((Date.now() - startedAt) / 1000));
      $value.text(formatPhotoTimer(seconds));
      $timer.toggleClass('reception-photo-timer--warn', seconds >= warnAfter && seconds < alertAfter)
            .toggleClass('reception-photo-timer--alert', seconds >= alertAfter);
    }, 1000);
  });
});
