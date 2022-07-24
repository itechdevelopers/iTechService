(function() {
  $(function() {
    $(document).on('keypress', '#message_content', function(e) {
      if(e.which === 13 && !e.shiftKey) {
        e.preventDefault();
        $(this).closest("form").submit();
      }
    })

    $(document).on('click', '[data-behavior~=close_secondary_form]', function(event) {
      event.preventDefault();
      $('#secondary_form_container').fadeOut().html('');
    })
  })
}).call(this);