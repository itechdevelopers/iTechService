App.cable.subscriptions.create({channel: 'UserNotificationChannel'}, {
  received(data) {
    if (!document.querySelector('#user_notifications').classList.contains('active-notifications')) {
      document.querySelector('#user_notifications').classList.add('active-notifications');
    }
    let notificationsContent = document.querySelector('#user_notifications').getAttribute('data-content');
    if (notificationsContent == null) {
      notificationsContent = '';
    }
    document.querySelector('#user_notifications').setAttribute('data-content', notificationsContent + data);
    document.querySelector('#user_notifications').click();
  }
})