class SalariesController < ApplicationController
  def index
    authorize Salary
    @salaries = policy_scope(Salary).search(search_params).page(params[:page])

    respond_to do |format|
      format.html
      format.json { render json: @salaries }
    end
  end

  def show
    @salary = find_record Salary
    respond_to do |format|
      format.html
      format.json { render json: @salary }
    end
  end

  def new
    @salary = authorize Salary.new(user_id: params[:user_id])
    @user = User.find(params[:user_id]) if params[:user_id].present?

    respond_to do |format|
      format.html
      format.json { render json: @salary }
    end
  end

  def edit
    @salary = find_record Salary
  end

  def create
    @salary = authorize Salary.new(salary_params)

    respond_to do |format|
      if @salary.save
        format.html { redirect_back_or salaries_path, notice: t('salaries.created') }
        format.json { render json: @salary, status: :created, location: @salary }
      else
        format.html { render action: 'new' }
        format.json { render json: @salary.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @salary = find_record Salary

    respond_to do |format|
      if @salary.update_attributes(salary_params)
        format.html { redirect_back_or salaries_path, notice: t('salaries.updated') }
        format.json { head :no_content }
      else
        format.html { render action: 'edit' }
        format.json { render json: @salary.errors, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    @salary = find_record Salary
    @salary.destroy

    respond_to do |format|
      format.html { redirect_to salaries_url }
      format.json { head :no_content }
    end
  end

  def salary_params
    params.require(:salary)
          .permit(:amount, :user, :user_id, :issued_at, :comment, :is_prepayment)
  end
end
