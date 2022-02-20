require 'vpim/vcard'

module ExportClients
  class Client < ApplicationRecord
    scope :in_city, ->(city) { where department_id: Department.in_city(city) }
  end

  def self.call(city_id)
    file = File.open File.join(Rails.root, 'tmp', 'clients.vcf'), 'w'
    clients = Client.in_city(city_id)

    clients.find_each do |client|
      card = Vpim::Vcard::Maker.make2 do |maker|
        maker.add_name do |name|
          name.family = client.surname
          name.given = client.name
          name.additional = client.patronymic
        end
        maker.add_tel client.phone_number
      end
      file << card
    end
    file
  end
end
