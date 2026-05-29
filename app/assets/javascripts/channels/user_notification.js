App.cable.subscriptions.create({channel: 'UserNotificationChannel'}, {
  received(data) {
    // Цвет иконки (синий / красный / красно-синий) зависит от набора типов
    // открытых уведомлений, который знает только сервер. Поэтому вместо ручного
    // выставления класса перезапрашиваем авторитетное состояние: эндпоинт
    // user_notifications заново отрисует data-content и нужный модификатор-класс.
    $.getScript('/notifications/user_notifications', function() {
      document.querySelector('#user_notifications').click();
    });
  }
})
