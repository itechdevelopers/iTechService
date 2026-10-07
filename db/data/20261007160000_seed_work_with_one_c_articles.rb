# frozen_string_literal: true

class SeedWorkWithOneCArticles < ActiveRecord::Migration[5.1]
  def up
    Ability.find_or_create_by!(name: 'work_with_one_c_articles') do |ability|
      ability.admin_assignable = false
    end
  end

  def down
    Ability.find_by(name: 'work_with_one_c_articles')&.destroy
  end
end
