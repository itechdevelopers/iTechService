# frozen_string_literal: true

class KarmaGroupsController < ApplicationController
  def index
    authorize KarmaGroup
    @karma_groups = policy_scope(Karma).where(karma_group_id: params[:karma_group_id])
    respond_to do |format|
      format.html { render 'index', layout: false }
    end
  end

  def show
    @karma_group = find_record KarmaGroup
    respond_to do |format|
      format.js
    end
  end

  def create
    @karma_group = authorize KarmaGroup.new(karma_group_params)
    respond_to do |format|
      if @karma_group.save
        format.js
      else
        format.js
      end
    end
  end

  def edit
    @karma_group = find_record KarmaGroup
    @karma_group.build_bonus
    respond_to do |format|
      format.js { render 'shared/show_modal_form' }
    end
  end

  def update
    @karma_group = find_record KarmaGroup
    respond_to do |format|
      if @karma_group.update_attributes(karma_group_params)
        format.js
      else
        format.js { render 'shared/show_modal_form' }
      end
    end
  end

  def destroy
    @karma_group = find_record KarmaGroup
    @karma_group_id = @karma_group.id
    @karmas = Karma.find @karma_group.karma_ids
    @karma_group.destroy
    respond_to do |format|
      format.js
    end
  end

  private

  def karma_group_params
    params.require(:karma_group).permit(
      :bonus_id, :karma_ids,
      bonus_attributes: [:id, :comment, :bonus_type_id]
    )
  end
end
