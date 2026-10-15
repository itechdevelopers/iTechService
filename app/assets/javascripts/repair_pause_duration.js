// Поле срока паузы (service_jobs/_pause_duration_field). Быстрая кнопка только
// заполняет число и единицу, а подсветка всегда следует за значениями полей:
// своё значение, совпавшее с кнопкой, подсвечивает её же. Окна вставляются
// ajax-ом, поэтому обработчики делегированы на document.
(function () {
  function syncPresets($field) {
    var amount = $.trim($field.find('.repair-pause-duration__amount').val());
    var unit = $field.find('.repair-pause-duration__unit').val();

    $field.find('.repair-pause-duration__preset').each(function () {
      var $preset = $(this);
      var presetAmount = String($preset.data('pause-amount'));
      var matches = presetAmount === ''
        ? amount === ''
        : presetAmount === amount && $preset.data('pause-unit') === unit;
      $preset.toggleClass('repair-pause-duration__preset--active', matches);
    });
  }

  $(document).on('click', '.repair-pause-duration__preset', function (e) {
    e.preventDefault();
    var $preset = $(this);
    var $field = $preset.closest('.repair-pause-duration');
    $field.find('.repair-pause-duration__amount').val($preset.data('pause-amount'));
    $field.find('.repair-pause-duration__unit').val($preset.data('pause-unit'));
    syncPresets($field);
  });

  $(document).on('input change', '.repair-pause-duration__amount, .repair-pause-duration__unit', function () {
    syncPresets($(this).closest('.repair-pause-duration'));
  });
})();
