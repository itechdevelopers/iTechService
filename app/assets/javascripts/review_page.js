$( document ).ready(function() {
    $('#review_value').barrating({
      theme: 'css-stars',
      showSelectedRating: false
    });

    // Mark review as viewed after 2 seconds (only for real users, not bots/previews)
    var reviewToken = $('.card.feedback').data('review-token');
    var csrfToken = $('.card.feedback').data('csrf-token');

    if (reviewToken) {
      setTimeout(function() {
        $.ajax({
          url: '/review/' + reviewToken + '/mark_viewed',
          method: 'POST',
          headers: { 'X-CSRF-Token': csrfToken },
          error: function(xhr, status, error) {
            console.log('Failed to mark review as viewed:', error);
          }
        });
      }, 2000); // 2 seconds
    }
});