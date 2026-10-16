// «Кря-контроль»: клик по строке сотрудника раскрывает под ней расшифровку —
// следующую строку таблицы. Строки без засчитанных работ не раскрываются
// (у них нет класса --expandable).
(function () {
  function toggle($row) {
    $row.toggleClass('quack-control__row--open');
    $row.next('.quack-control__details-row').toggleClass('quack-control__details-row--open');
  }

  $(document).on('click', '.quack-control__row--expandable', function () {
    toggle($(this));
  });

  $(document).on('keydown', '.quack-control__row--expandable', function (e) {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    e.preventDefault();
    toggle($(this));
  });
})();
