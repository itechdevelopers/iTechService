// Фича «Строгий ремонт».
// Цикл 2: клик по «глазу» только снимает blur (без диалога/маркера —
// это циклы 3–4). Делегированный обработчик переживает ajax-перерисовки.
$(document).on('click', '.strict-repair__reveal', function (e) {
  e.preventDefault();
  $(this).closest('.strict-repair').addClass('strict-repair--revealed');
});
