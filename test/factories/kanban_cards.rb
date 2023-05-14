FactoryGirl.define do
  factory :kanban_card, class: 'Kanban::Card' do
    title "MyString"
    description "MyText"
    author nil
    column nil
  end
end
