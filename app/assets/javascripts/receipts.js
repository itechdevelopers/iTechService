App.Receipts = {
  init: function() {
    const $form = $('#receipt-form')

    if($form.length > 0) {
      $(document).on('click', '[data-behavior~=remove-receipt-product]', function(event) {
        event.preventDefault()
        App.Receipts.removeProduct(this)
      })

      $form.on('submit', function() {
        setTimeout(function() {
          $form.find(':input[type=submit]').prop('disabled', false)
        }, 1000)
      })
    } else {
      $(document).off('click', '[data-behavior~=remove-receipt-product]')
    }
  },

  removeProduct: function(sender) {
    const $fields = $(sender).closest('.product-fields')
    $fields.remove()
    this.calculate()
  },

  calculate: function() {
    const $form = $('#receipt-form');
    const $products = $form.find('.product-fields');
    let sum = 0;
    $products.each(function() {
      const price = $('.price', this).val();
      const quantity = $('.quantity', this).val();
      return sum += price * quantity;
    });
    $('#receipt-sum-value').val(sum);
    $('.receipt-sum', $form).text(accounting.formatMoney(sum));
    $('#receipt-sum-in-words').val(sum2str(sum));
  }
}

$(function() {
  App.Receipts.init()
})