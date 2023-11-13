class AddUpdatedTextToRecordEdits < ActiveRecord::Migration[5.1]
  def up
    add_column :record_edits, :updated_text, :text
  
    dn_ids = DeviceNote.select { |dn| !dn.record_edits.empty? }.map(&:id)
    edits = dn_ids.map { |id| DeviceNote.find(id).record_edits.order(updated_at: :desc).limit(1).first }

    dn_ids.each do |dn_id|
      dn_last_edit = RecordEdit.where(editable_id: dn_id).order(updated_at: :desc).limit(1).first
      dn_last_edit.update(updated_text: DeviceNote.find(dn_id).content)
    end
  end

  def down
    remove_column :record_edits, :updated_text
  end
end
