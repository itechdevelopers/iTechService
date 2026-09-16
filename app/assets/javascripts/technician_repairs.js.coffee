$(document).on 'click', '.technician-repairs__row > td', ->
  $row = $(this).closest('tr')
  $row.toggleClass('technician-repairs__row--open')
  $row.nextUntil('.technician-repairs__row').toggle()
  return
