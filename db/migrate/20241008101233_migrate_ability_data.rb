class MigrateAbilityData < ActiveRecord::Migration[5.1]
  def change
    ability_names = %w[
      manage_wiki
      manage_salary
      print_receipt
      manage_timesheet
      manage_schedule
      edit_clients
      view_feedback_notifications
      edit_tasks_user_comment
      view_repair_parts
      comment_users
      see_stale_service_jobs
      manage_trade_in
      inventory
      view_reports
      view_feedbacks_in_city
      manage_stocks
      edit_price_in_sale
      view_quick_orders_and_free_jobs_everywhere
      move_transfers
      see_all_users
      access_all_departments
      show_spare_parts_qty
      request_review
      show_reviews
      perform_service_center_tasks
      perform_engraving_tasks
      set_new_client_department
      change_client_department
      view_god_eye
      view_bad_review_announcements
      work_with_electronic_queues
    ].freeze

    ability_names.each do |ability_name|
      Ability.create!(name: ability_name)
    end

    User.find_each do |user|
      user.abilities_old.each do |ability_name|
        ability = Ability.find_by(name: ability_name)
        UserAbility.create!(user_id: user.id, ability_id: ability.id)
      end
    end
  end
end
