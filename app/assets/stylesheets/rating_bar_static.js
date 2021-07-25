$( document ).ready(function() {
  const value = $('#rating-bar-static-value').val();
  const content = $('#rating-bar-static-content').val();
  const items = [1,2,3,4,5];
  $.each(items, function (_i, item) {
    $('#rating-bar-static-select').append($('<option>', { 
        value: item,
        text : item 
    }));
  });
  $("#rating-bar-static-select").val(value).change();
  $('#rating-bar-static-select').barrating({
    theme: 'css-stars',
    showSelectedRating: false,
    readonly: true,
  });
  tippy('.rating-bar-static', {
    content,
  });
});