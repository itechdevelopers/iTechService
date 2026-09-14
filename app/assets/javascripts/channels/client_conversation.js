// Лента диалога с клиентом.
//
// Одна и та же реплика приходит в браузер двумя путями: её рисует ответ на
// форму и она же прилетает по ActionCable (броадкаст уходит в after_create,
// то есть ещё внутри POST-запроса, и вполне может опередить AJAX-ответ).
// Поэтому вставка обязана быть идемпотентной — полагаться на порядок нельзя.
// Через ту же функцию идёт и подмена «[фото загружается…]» самой картинкой.
window.ClientChat = window.ClientChat || {};

window.ClientChat.upsertMessage = function (id, html) {
  // Контейнер ищем заново на каждый вызов: взятие в работу и закрытие
  // перерисовывают карточку целиком, и сохранённая ссылка устарела бы.
  var container = document.getElementById('client_chat_feed');
  if (!container) { return; }

  var existing = document.getElementById('client_message_' + id);
  if (existing) {
    existing.outerHTML = html;
  } else {
    $(container).append(html);
  }
  container.scrollTop = container.scrollHeight;
};

// Подписка поднимается только на карточке — на остальных страницах
// контейнера нет и канал не открывается.
$(function () {
  var feed = document.getElementById('client_chat_feed');
  if (!feed || !feed.dataset.conversationId) { return; }

  App.cable.subscriptions.create(
    { channel: 'ClientConversationChannel', id: feed.dataset.conversationId },
    {
      received: function (data) {
        window.ClientChat.upsertMessage(data.id, data.html);
      }
    }
  );
});
