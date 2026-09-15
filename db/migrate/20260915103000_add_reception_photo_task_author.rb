class AddReceptionPhotoTaskAuthor < ActiveRecord::Migration[5.1]
  # Автор задачи нужен отдельно от исполнителя (performer_id) и от приёмщика
  # работы (service_jobs.user_id): задачу «ремонт» может дописать к чужой работе
  # любой сотрудник, и отвечать за фото по ней должен он, а не приёмщик.
  def change
    add_reference :device_tasks, :creator, index: true
    add_reference :service_jobs, :reception_photo_responsible, index: true
  end
end
