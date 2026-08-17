class ApplicationJob < ActiveJob::Base
  private

  # ⚠️ ActiveJob 5.1 hands a retry_on block the exception CLASS, not the raised
  # object: active_job/exceptions.rb:50 does `yield self, exception`, where
  # `exception` is the class registered with retry_on (fixed upstream in 5.2).
  # Calling error.message there raises NoMethodError from inside the failure
  # handler — the job then dies for real and whatever the handler was supposed
  # to send (a ❌ to the employee) never goes out.
  #
  # Use this instead of interpolating the argument directly; it also keeps
  # working once the gem starts passing a proper exception.
  def error_label(error)
    error.is_a?(Exception) ? "#{error.class}: #{error.message}" : error.to_s
  end
end
