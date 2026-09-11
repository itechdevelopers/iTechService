// Живая лента диалога с клиентом. Подписка поднимается только на карточке —
// на остальных страницах контейнера нет и канал не открывается.
$(function () {
  var feed = document.getElementById('client_chat_feed');
  if (!feed || !feed.dataset.conversationId) { return; }

  App.cable.subscriptions.create(
    { channel: 'ClientConversationChannel', id: feed.dataset.conversationId },
    {
      received: function (data) {
        // Ищем каждый раз заново: взятие в работу и закрытие перерисовывают
        // карточку целиком, и сохранённая ссылка на узел устарела бы.
        var container = document.getElementById('client_chat_feed');
        if (!container) { return; }

        var existing = document.getElementById('client_message_' + data.id);
        if (existing) {
          // Своя же реплика (её дорисовала форма) либо догрузившееся фото.
          existing.outerHTML = data.html;
        } else {
          $(container).append(data.html);
        }
        container.scrollTop = container.scrollHeight;
      }
    }
  );
});
