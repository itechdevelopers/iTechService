$(function() {
  if($('#quick_order_form').length > 0) {
    $(document).on('click', '[data-behavior~=quick_orders-copy_phone]', function(event) {
      const target = $(event.target).data('target')
      const client_phone = $('#client_search').val().split('/')[1].match(/[0-9]/g).join('')
      $(target).val(client_phone)
      event.preventDefault()
    })
  }
})
