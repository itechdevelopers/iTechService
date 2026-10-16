// Поиск клиента для привязки к диалогу. Свой, а не общий пикер из формы
// приёмки: тот завязан на её разметку и на абсолютное позиционирование списка.
// Клик по иконке в топбаре раскрывает всплывашку, а не уходит на страницу:
// Bootstrap переход по ссылке сам не отменяет. href оставлен рабочим — по нему
// по-прежнему можно открыть раздел в новой вкладке средней кнопкой.
$(document).on('click', '#client_conversations_icon', function (event) {
  event.preventDefault();
});

// Строка списка открывает диалог по клику в любом её месте. Ссылки внутри
// строки (карточка клиента) ведут своим адресом, а клик, которым выделили
// текст, переходом не считается — из строки копируют номер и реплики.
// Средняя кнопка и Ctrl/Cmd открывают диалог в новой вкладке, как у ссылки.
$(document).on('click auxclick', '.client-chat-list__row', function (event) {
  if (event.type === 'auxclick' && event.button !== 1) { return; }
  if ($(event.target).closest('a, button, input, select, textarea').length) { return; }
  if (String(window.getSelection()) !== '') { return; }

  var url = $(this).data('href');
  if (event.type === 'auxclick' || event.ctrlKey || event.metaKey) {
    window.open(url, '_blank');
  } else {
    window.location.href = url;
  }
});

// Размер переписки в карточке диалога: ширина ленты с формой ответа и высота
// ленты. Хранится в браузере, а не у сотрудника — на ноутбуке и на широком
// мониторе удобны разные размеры. localStorage бывает недоступен (приватный
// режим), тогда размер просто не запоминается.
//
// Размер — CSS-переменные на #client_chat_card: взятие в работу и закрытие
// заменяют его содержимое, а сам элемент остаётся, и новая разметка
// подхватывает размер без повторного применения.
(function () {
  var STORAGE_KEY = 'clientChatWindowSize';
  var MIN_WIDTH = 480;
  var MIN_FEED_HEIGHT = 150;

  function load() {
    try {
      return JSON.parse(window.localStorage.getItem(STORAGE_KEY)) || {};
    } catch (e) {
      return {};
    }
  }

  function save(size) {
    try {
      window.localStorage.setItem(STORAGE_KEY, JSON.stringify(size));
    } catch (e) { /* размер не запомнится, окно работает и так */ }
  }

  function setPx(element, name, value) {
    if (value) {
      element.style.setProperty(name, value + 'px');
    } else {
      element.style.removeProperty(name);
    }
  }

  function apply(card, size) {
    setPx(card, '--client-chat-dialog-width', size.width);
    setPx(card, '--client-chat-feed-height', size.height);
  }

  function scrollFeedToBottom() {
    var feed = document.getElementById('client_chat_feed');
    if (feed) { feed.scrollTop = feed.scrollHeight; }
  }

  $(function () {
    var card = document.getElementById('client_chat_card');
    if (!card) { return; }

    var size = load();
    apply(card, size);
    // Лента уже прокручена вниз подпиской канала, но до того, как ей сменили
    // высоту: после сужения низ переписки ушёл бы из виду.
    scrollFeedToBottom();

    $(card).on('mousedown', '.client-chat__width-handle, .client-chat__height-handle', function (event) {
      if (event.button !== 0) { return; }
      // Иначе протяжка мышью выделяет текст переписки.
      event.preventDefault();

      var byWidth = $(this).hasClass('client-chat__width-handle');
      var dialog = $(this).closest('.client-chat__dialog')[0];
      var feed = document.getElementById('client_chat_feed');
      // Смещение мыши — в координатах окна (client*), не страницы (page*):
      // сжатая лента укорачивает прокрученную до низа страницу, браузер
      // уменьшает scrollY, и page* добавил бы к ходу мыши этот сдвиг — ручка
      // убегала бы от курсора.
      var startX = event.clientX;
      var startY = event.clientY;
      var startWidth = dialog.offsetWidth;
      var startHeight = $(feed).height();
      var atBottom = feed.scrollTop + feed.clientHeight >= feed.scrollHeight - 2;
      var cursorClass = byWidth ? 'client-chat-resizing--width' : 'client-chat-resizing--height';

      $('body').addClass(cursorClass);

      $(document).on('mousemove.clientChatResize', function (move) {
        if (byWidth) {
          var width = Math.max(MIN_WIDTH, startWidth + move.clientX - startX);
          // Дотянули до края — снимаем ограничение, а не храним ширину экрана:
          // на мониторе пошире переписка тоже должна занимать всё место.
          size.width = width < dialog.parentNode.clientWidth ? width : null;
        } else {
          size.height = Math.max(MIN_FEED_HEIGHT, startHeight + move.clientY - startY);
        }
        apply(card, size);
        if (atBottom) { scrollFeedToBottom(); }
      });

      $(document).one('mouseup', function () {
        $(document).off('mousemove.clientChatResize');
        $('body').removeClass(cursorClass);
        save(size);
      });
    });

    $(card).on('dblclick', '.client-chat__width-handle, .client-chat__height-handle', function () {
      if ($(this).hasClass('client-chat__width-handle')) {
        size.width = null;
      } else {
        size.height = null;
      }
      apply(card, size);
      save(size);
      scrollFeedToBottom();
    });
  });
})();

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
