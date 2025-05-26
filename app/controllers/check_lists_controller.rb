# frozen_string_literal: true

class CheckListsController < ApplicationController
  def index
    authorize CheckList
    @check_lists = CheckList.all
  end

  def show
    @check_list = find_record CheckList
  end

  def new
    @check_list = authorize CheckList.new
    @check_list_item = @check_list.check_list_items.build
  end

  def edit
    @check_list = find_record CheckList
  end

  def create
    @check_list = authorize CheckList.new(check_list_params)

    if @check_list.save
      redirect_to check_lists_path, notice: t('check_lists.created')
    else
      render action: 'new'
    end
  end

  def update
    @check_list = find_record CheckList
  
    if @check_list.update(check_list_params)
      redirect_to check_lists_path, notice: t('check_lists.updated')
    else
      render action: 'edit'
    end
  end

  def destroy
    @check_list = find_record CheckList
    @check_list.destroy

    redirect_to check_lists_url, notice: t('check_lists.deleted')
  end

  private

  def check_list_params
    params.require(:check_list)
          .permit(:name, :description, :entity_type, :active,
          check_list_items_attributes: [:id, :question, :required, :position, :_destroy])
  end
end
