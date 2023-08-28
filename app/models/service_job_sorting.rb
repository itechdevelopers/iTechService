class ServiceJobSorting < ApplicationRecord
  belongs_to :user, optional: true

  SORTING_LIST = [
    {title: 'По умолчанию', direction: 'asc', column: 'created_at'},
    {title: 'Время до возврата', direction: 'asc', column: 'return_at'},
    {title: 'Время до возврата, за исключением «Время вышло»', direction: 'asc', column: 'other'},
  ]
end
