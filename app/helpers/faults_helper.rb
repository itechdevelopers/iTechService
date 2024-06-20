module FaultsHelper
  def header_fault_button
    link_to glyph('minus-circle'), new_fault_path, remote: true, id: 'header-fault-link'
  end

  def fault_causers_collection
    User.active.staff.order(:name)
  end

  def fault_kinds_collection
    FaultKind.select(:id, :name).ordered
  end

  def fault_kinds_data
    FaultKind.all.map { |kind|
      [kind.id, [[:is_financial, kind.financial?], [:description, textile_to_html(kind.description)]].to_h]
    }.to_h
  end
end
