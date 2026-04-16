(function() {
  App.Inputs.Location = {
    show_departments: function(){
      $('#departments_list').removeClass('hidden')
      $('#locations_list').addClass('hidden')
      $('#less_popular_list').addClass('hidden')
      setTimeout(function(){ $('#locations_select_button').dropdown('toggle') }, 1)
    },

    show_less_popular: function(){
      $('#less_popular_list').removeClass('hidden')
      $('#locations_list').addClass('hidden')
      $('#departments_list').addClass('hidden')
      setTimeout(function(){ $('#locations_select_button').dropdown('toggle') }, 1)
    },

    show_locations: function(list){
      $('#departments_list').addClass('hidden')
      $('#less_popular_list').addClass('hidden')
      $('#locations_list').html(list).removeClass('hidden')
      $('#locations_select_button').dropdown('toggle')
    }
  }

  $(function(){
    $(document).on('click', '#location_input .location-item', function(event) {
      $('#location_value').text($(this).text())
      $('#location_id').val($(this).data('id'))
      return event.preventDefault()
    })

    $(document).on('click', '#location_input [data-behavior~=show_departments]', function(event){
      App.Inputs.Location.show_departments()
      return event.preventDefault()
    })

    $(document).on('click', '#location_input [data-behavior~=show_less_popular]', function(event){
      App.Inputs.Location.show_less_popular()
      return event.preventDefault()
    })
  })
}).call(this)
