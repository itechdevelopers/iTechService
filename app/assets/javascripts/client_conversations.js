// Поиск клиента для привязки к диалогу. Свой, а не общий пикер из формы
// приёмки: тот завязан на её разметку и на абсолютное позиционирование списка.
$(function () {
  var timer = null;

  // Делегирование на document: карточка перерисовывается целиком при взятии в
  // работу, закрытии и смене города, и обработчик, повешенный на сам input,
  // после первой же перерисовки отвалился бы.
  $(document).on('keyup', '.client-chat__client-query', function () {
    var input = this;
    var picker = $(input).closest('.client-chat__client-picker');

    if (timer) { clearTimeout(timer); }

    if ($.trim(input.value) === '') {
      picker.find('.client-chat__client-results').empty().hide();
      return;
    }

    timer = setTimeout(function () {
      $.getScript(picker.data('url') + '?q=' + encodeURIComponent(input.value));
    }, 400);
  });

  $(document).on('click', function (event) {
    if ($(event.target).closest('.client-chat__client-picker').length === 0) {
      $('.client-chat__client-results').hide();
    }
  });
});
