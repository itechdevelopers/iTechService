(function() {
  $(function() {
    $(document).on('keypress', '#device_note_content', function(e) {
      if(e.which === 13 && !e.shiftKey) {
        e.preventDefault();
        $(this).closest("form").submit();
      }
    })
  })
}).call(this);