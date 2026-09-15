// Иконка «Диалоги» в топбаре. По сигналу из канала перезапрашиваем число у
// сервера, а не считаем на клиенте: счёт зависит от города сотрудника, и
// знает его только сервер. Тот же приём, что у колокольчика уведомлений.
$(function () {
  if (!document.getElementById('client_conversations_counter')) { return; }

  App.cable.subscriptions.create({ channel: 'ClientConversationCounterChannel' }, {
    received: function () {
      $.getScript('/client_conversations/counter');
    }
  });
});
