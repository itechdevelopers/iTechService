class Entities::DeviceNoteEntity < Grape::Entity
  expose :id, :content, :created_at
  expose :user do |device_note, _|
    device_note.user.short_name
  end
end
