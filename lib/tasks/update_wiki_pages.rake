namespace :update do
  desc 'Обновление полей WikiPage'
  task wiki_pages: :environment do
    puts 'Обновление страниц wiki'
    WikiPage.update_all private: false
    puts 'Обновление завершено'
  end
end
