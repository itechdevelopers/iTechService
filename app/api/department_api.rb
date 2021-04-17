class DepartmentApi < Grape::API
  version 'v1', using: :path

  before { authenticate! }

  desc 'Show departments'
  get 'departments' do
    departments = Department.all
    present_record departments
  end
end
