class ServiceJobSorting < ApplicationRecord
  belongs_to :user, optional: true

  SORTING_LIST = [
    {title: 'По умолчанию', direction: 'asc', column: 'created_at'},
    {title: 'Время до возврата', direction: 'asc', column: 'return_at'},
    {title: 'Время до возврата, за исключением «Время вышло»', direction: 'asc', column: 'other'},
  ]

  FILTER_LIST = [
    {title: 'более 3 часов', type: 'info', url: '/?only=info'},
    {title: 'от 3 до 1 часа', type: 'warning', url: '/?only=warning'},
    {title: 'менее 1 часа', type: 'pre-danger', url: '/?only=danger'},
    {title: 'время вышло', type: 'danger', url: '/?only=time-out'},
  ]
end
