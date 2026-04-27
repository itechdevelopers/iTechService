$(function () {
  var $root = $('.glass-sticking');
  if (!$root.length) return;

  var url = $root.data('recipients-url');
  var notifyUrl = $root.data('notify-url');
  var $modes = $root.find('input[name="mode"]');
  var $search = $root.find('input[name="name"]');
  var debounceTimer = null;

  function reload() {
    var mode = $root.find('input[name="mode"]:checked').val();
    var name = $search.val();
    $.ajax({
      url: url,
      method: 'GET',
      dataType: 'script',
      data: { mode: mode, name: name }
    });
  }

  $modes.on('change', reload);

  $search.on('input', function () {
    clearTimeout(debounceTimer);
    debounceTimer = setTimeout(reload, 300);
  });

  $root.on('click', '.glass-sticking__btn', function () {
    var $btn = $(this);
    var status = $btn.data('status');
    var recipientId = $btn.closest('.glass-sticking__card').data('user-id');
    $btn.prop('disabled', true);
    $.ajax({
      url: notifyUrl,
      method: 'POST',
      dataType: 'script',
      data: { recipient_id: recipientId, status: status }
    }).always(function () {
      setTimeout(function () { $btn.prop('disabled', false); }, 1000);
    });
  });
});
