window.App ||= {}

App.init = ->
  App.current_user_id = $('#profile_link').data('id')

  #== Open external links in new window
#  $("a[href^='http']").attr('target', '_blank')

App.showModal = ->
  $("#modal:hidden").modal('show');

App.closeModal = ->
  $("#modal").modal('hide').html('');

App.closeModalForm = ->
  $("#modal_form").modal('hide').html('');

jQuery ->
  App.init()