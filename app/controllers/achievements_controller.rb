class AchievementsController < ApplicationController
  def index
    authorize Achievement
    @achievements = Achievement.all
  end

  def new
    authorize Achievement
    @achievement = Achievement.new
    render 'form'
  end

  def create
    @achievement = authorize Achievement.new(achievement_params)
    if @achievement.save
      redirect_to achievements_path, notice: 'Достижение успешно добавлено'
    else
      render 'new'
    end
  end

  def edit
    @achievement = find_record Achievement
    render 'form'
  end

  def update
    @achievement = find_record Achievement
    if @achievement.update(achievement_params)
      redirect_to achievements_path, notice: 'Достижение успешно обновлено'
    else
      render 'edit'
    end
  end

  def destroy
    @achievement = find_record Achievement
    return unless @achievement.destroy

    redirect_to achievements_path, notice: 'Достижение успешно удалено'
  end

  def icon_url
    authorize Achievement
    achievement = Achievement.find(params[:id])
    render json: { icon_url: achievement.icon.url }
  end

  private

  def achievement_params
    params.require(:achievement).permit(:name, :icon, :icon_mini)
  end
end
