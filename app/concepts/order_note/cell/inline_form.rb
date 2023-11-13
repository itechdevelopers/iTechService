module OrderNote::Cell
  class InlineForm < BaseCell
    private

    include FormCell

    def submit_label
      I18n.t 'order_notes.form.update'
    end
  end
end