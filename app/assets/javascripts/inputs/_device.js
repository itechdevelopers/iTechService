(function(){
  App.Inputs.Device = {
    check_imei: function() {
      var $input = $('.device_input')
      var item_id = $input.find('.item_id').val()
      $.getJSON("/items/" + item_id + "/check_status", function(data) {
        var $search_input = $input.find('.item_search')

        if (data.status_info.length > 0) {
          $search_input.attr('data-status', data.status)
          $search_input.tooltip('destroy')
          $search_input.attr('title', data.status_info)
          $search_input.tooltip()
        } else {
          $search_input.attr('data-status', '')
          $search_input.attr('title', '')
          $search_input.tooltip('destroy')
        }
      })
    },
    check_1c_status: function () {
      const $input = $('.device_input')
      const item_id = $input.find('.item_id').val()
      const $status_field = $input.find('.device_1c_status')
      fetch(`/items/${item_id}/check_1c_status`)
        .then(response => response.json())
        .then(data => {
          $status_field.text(data.status)
        })
    },
    check_1c_status_by_sn: function () {
      const $input = $('.device_input');
      const serial_number = $('#item_search').val();
      const $status_field = $input.find('.device_1c_status');

      fetch(`/items/check_1c_status_by_sn?serial_number=${encodeURIComponent(serial_number)}`)
          .then(response => response.json())
          .then(data => {
            $status_field.text(data.status);
          });
    }
  }

  $(function(){
    $('.device-input-container>.item_search').autocomplete({
      source: '/devices/autocomplete.json',
      focus: function(event, ui) {
        var isTextarea = $(this).is('textarea')
        if (isTextarea) {
          var parts = ui.item.label.split(' / ')
          $(this).val(parts.join('\n'))
        } else {
          $(this).val(ui.item.label)
        }
        return false
      },
      select: function(event, ui) {
        var isTextarea = $(this).is('textarea')
        if (isTextarea) {
          var parts = ui.item.label.split(' / ')
          $(this).val(parts.join('\n'))
        } else {
          $(this).val(ui.item.label)
        }
        $(this).siblings('.item_id').val(ui.item.value)
        $(this).siblings('.edit_item_btn').attr('href', "/devices/" + ui.item.value + "/edit.js").attr('data-remote', true)
        $(this).siblings('.show_item_btn').attr('href', "/devices/" + ui.item.value + ".js").attr('data-remote', true)
        App.Inputs.Device.check_imei()
        App.Inputs.Device.check_1c_status()

        // Auto-populate trademark and device_group from product_group (v2 only)
        var $form = $(this).closest('form.service_job_form')
        if ($form.data('form-version') === 'v2') {
          if (ui.item.trademark !== undefined && ui.item.trademark !== null) {
            $('#service_job_trademark').val(ui.item.trademark)
          }
          if (ui.item.product_line !== undefined && ui.item.product_line !== null) {
            $('#service_job_device_group').val(ui.item.product_line)
          }
        }

        return false
      },
      search: function( event, ui ) {
        App.Inputs.Device.check_1c_status_by_sn()
      }
    })
  })
}).call(this)
