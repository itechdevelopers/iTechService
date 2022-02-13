FactoryBot.define do
  factory :announcement do
    active { true }
    kind { 'help' }
    content { 'Content' }
  end
end
