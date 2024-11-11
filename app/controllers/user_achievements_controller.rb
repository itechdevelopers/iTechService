class UserAchievementsController < ApplicationController
  before_action :set_user
  before_action :set_achievement, only: %i[destroy]
  def new
    authorize UserAchievement
    @user_achievement = @user.user_achievements.build

    respond_to(&:js)
  end

  def create
    authorize UserAchievement
    @user_achievement = @user.user_achievements.build(achievements_params.merge(achieved_at: DateTime.current))
    if @user_achievement.save
      create_notification
      render :create, notice: 'Достижение успешно добалено пользователю'
    else
      head :unprocessable_entity, notice: 'Ошибка при добавлении достижения пользователю'
    end
  end

  def destroy
    authorize @user_achievement
    @user_achievement.destroy
    respond_to(&:js)
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end

  def set_achievement
    @user_achievement = @user.user_achievements.find(params[:id])
  end

  def achievements_params
    params.require(:user_achievement).permit(:comment, :achievement_id)
  end

  def create_notification
    notification = Notification.create(user: @user,
                                       url: user_url(@user, anchor: 'achievements_tab'),
                                       referenceable: @user_achievement,
                                       message: "Получено достижение: #{@user_achievement.achievement.name}")
    UserNotificationChannel.broadcast_to(notification.user, notification) unless notification.errors.any?
  end
end
