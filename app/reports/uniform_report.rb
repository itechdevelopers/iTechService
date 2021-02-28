class UniformReport < BaseReport
  def call
    users = User.active.where.not(uniform_sex: nil).where.not(uniform_sex: '')
    users = users.in_department(department) if department
    users = users.order(:uniform_sex, :uniform_size).group(:uniform_sex, :uniform_size)
    users = users.select(:uniform_sex, :uniform_size, "array_agg(surname||' '||name||' '||patronymic) staff", 'count(*) as qty')
    result[:uniforms] = users.as_json

    result
  end
end
