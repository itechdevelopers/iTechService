class TaskTemplatesController < ApplicationController
  def index
    authorize TaskTemplate
    @task_templates = TaskTemplatesDecorator.decorate TaskTemplate.roots.ordered

    respond_to do |format|
      format.html
      format.js
    end
  end

  def new
    @task_template = authorize TaskTemplate.new(parent_id: params[:parent_id], position: params[:position].permit!)
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def create
    @task_template = authorize TaskTemplate.new(task_template_params)
    respond_to do |format|
      if @task_template.save
        format.html { redirect_to (@task_template.parent.presence || task_templates_path), notice: t('task_templates.created') }
      end
      format.html
    end
  end

  def show
    @task_template = find_record(TaskTemplate).decorate
    @task_templates = TaskTemplatesDecorator.decorate(@task_template.children.ordered)
    respond_to do |format|
      format.html { render 'index' }
      format.js { render @task_template.has_children? ? 'index' : 'show' }
    end
  end

  def edit
    @task_template = find_record TaskTemplate
    respond_to do |format|
      format.html { render 'form' }
    end
  end

  def update
    @task_template = find_record TaskTemplate
    respond_to do |format|
      if @task_template.update task_template_params
        format.html { redirect_to (@task_template.parent || task_templates_path), notice: t('task_templates.updated') }
      else
        format.html { render 'form' }
      end
    end
  end

  def destroy
    @task_template = find_record TaskTemplate
    @task_template.destroy
    respond_to do |format|
      format.html { redirect_to task_templates_path, notice: t('task_templates.destroyed') }
    end
  end

  private

  def task_template_params
    params.require(:task_template).permit(:content, :icon, :position, :parent_id)
  end
end