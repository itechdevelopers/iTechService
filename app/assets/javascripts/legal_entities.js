// Привязка организации к подразделению в два клика: организация слева, затем
// «Привязать» у подразделения. Выбор живёт в переменной, а не в разметке: ответы
// link/unlink/save перерисовывают обе колонки, и выделение пропало бы вместе с ними.
var legalEntitiesBoard = (function () {
  var selected = null;

  function apply() {
    var board = $('.legal-entities-board');
    if (board.length === 0) { return; }

    if (selected && board.find('.legal-entities-board__entity[data-legal-entity-id="' + selected.id + '"]').length === 0) {
      selected = null;
    }

    board.find('.legal-entities-board__entity').each(function () {
      var entity = $(this);
      entity.toggleClass('legal-entities-board__entity--selected',
                         selected !== null && entity.data('legalEntityId') === selected.id);
    });

    var hint = board.find('.legal-entities-board__hint');
    hint.text(selected ? String(hint.data('selectedTemplate')).replace('__ENTITY__', selected.name) : hint.data('idle'));

    board.find('.legal-entities-board__link-button').each(function () {
      var button = $(this);
      var active = selected !== null && button.data('linkedEntityId') !== selected.id;
      button.toggleClass('legal-entities-board__link-button--active', active);
      if (!active) { return; }

      var confirmText = String(button.data('confirmTemplate')).replace('__ENTITY__', selected.name);
      button.attr('href', String(button.data('urlTemplate')).replace('__ID__', selected.id));
      // jquery_ujs читает подтверждение через .data(), а он кэширует атрибут при
      // первом чтении, — обновляем и атрибут, и кэш.
      button.attr('data-confirm', confirmText).data('confirm', confirmText);
    });
  }

  $(document).on('click', '.legal-entities-board__entity', function (event) {
    if ($(event.target).closest('a, button').length > 0) { return; }

    var entity = $(this);
    var id = entity.data('legalEntityId');
    selected = (selected && selected.id === id) ? null : { id: id, name: String(entity.data('legalEntityName')) };
    apply();
  });

  // Вкладку с актом открывает сам клик по ссылке: window.open из ответа сервера
  // браузер заблокировал бы как всплывающее окно. Модалку закрываем отдельно —
  // data-dismiss у Bootstrap отменил бы переход по ссылке.
  $(document).on('click', '.legal-entities-board__open-act', function () {
    $('#modal_form').modal('hide');
  });

  return { apply: apply };
})();
