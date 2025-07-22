# iTechService Notification System Implementation Guide

## Overview

The iTechService application implements a comprehensive notification system with role-based targeting, real-time delivery, and polymorphic associations. This guide provides detailed information for implementing custom notifications and role-based notification filtering.

## Core Components

### 1. Notification Model

**File:** `app/models/notification.rb`

```ruby
class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :referenceable, polymorphic: true, optional: true

  scope :not_closed, -> { where(closed_at: nil) }
  
  validates :user_id, :message, presence: true

  def close
    update(closed_at: Time.zone.now)
  end

  def closed?
    closed_at.present?
  end
end
```

**Database Schema:**
```ruby
create_table :notifications do |t|
  t.references :referenceable, polymorphic: true
  t.references :user, foreign_key: true, null: false
  t.string :url
  t.datetime :closed_at
  t.text :message
  t.timestamps
end
```

### 2. User Role System

**Available Roles:**
```ruby
ROLES = %w[
  admin software media technician marketing
  developer supervisor manager superadmin
  driver api universal engraver
].freeze
```

**Role-Based Scopes:**
```ruby
scope :any_admin, -> { where(role: %w[admin superadmin]) }
scope :superadmins, -> { where(role: 'superadmin') }
scope :software, -> { where(role: 'software') }
scope :media, -> { where(role: 'media') }
scope :technician, -> { where(role: 'technician') }
scope :not_technician, -> { where('role <> ?', 'technician') }
scope :marketing, -> { where(role: 'marketing') }
scope :supervisor, -> { where(role: 'supervisor') }
scope :manager, -> { where(role: 'manager') }
scope :staff, -> { where.not(role: 'api') }
```

**Department-Based Filtering:**
```ruby
scope :in_department, ->(department) { where(department_id: department) }
scope :in_city, ->(city) { where department_id: Department.in_city(city) }
```

## Creating Custom Notifications

### Method 1: Direct Notification Creation

```ruby
# Simple notification creation
notification = Notification.create(
  user: target_user,
  message: "Your notification message",
  url: "/path/to/relevant/resource",
  referenceable: related_object # optional
)

# Broadcast real-time notification
UserNotificationChannel.broadcast_to(notification.user, notification)
```

### Method 2: Bulk Notification Creation

```ruby
# In ApplicationController
def create_notifications_for_users(user_ids, messages)
  notifications = []
  user_ids.zip(messages).each do |user_id, message|
    notification = Notification.create(
      user_id: user_id, 
      message: message
    )
    notifications << notification
    UserNotificationChannel.broadcast_to(notification.user, notification)
  end
  notifications
end
```

### Method 3: Model-Based Notification Pattern

Make your model "notifiable" by implementing these methods:

```ruby
class YourModel < ApplicationRecord
  def notification_recipients
    # Return array of users who should receive notifications
    # Example: return all managers in the same department
    User.manager.in_department(self.department_id)
  end

  def notification_message
    # Return the notification message
    "New update for #{self.name}"
  end

  def url
    # Return the URL to link to in the notification
    Rails.application.routes.url_helpers.your_model_path(self)
  end
end
```

Then create notifications in your controller:

```ruby
def create_notifications
  if @your_model.respond_to?(:notification_recipients)
    message = @your_model.notification_message
    @your_model.notification_recipients.each do |recipient|
      notification = Notification.create(
        user_id: recipient.id,
        message: message,
        url: @your_model.url,
        referenceable: @your_model
      )
      UserNotificationChannel.broadcast_to(notification.user, notification)
    end
  end
end
```

## Role-Based Notification Filtering

### 1. Using Role Scopes

```ruby
# Notify all admins
User.any_admin.each do |admin|
  Notification.create(
    user: admin,
    message: "Admin-specific notification"
  )
end

# Notify all technicians
User.technician.each do |tech|
  Notification.create(
    user: tech,
    message: "Technician-specific notification"
  )
end

# Notify all software and media roles
(User.software.to_a + User.media.to_a).uniq.each do |user|
  Notification.create(
    user: user,
    message: "Software/Media notification"
  )
end
```

### 2. Department-Based Filtering

```ruby
# Notify users in specific department
department_id = 1
User.in_department(department_id).each do |user|
  Notification.create(
    user: user,
    message: "Department-specific notification"
  )
end

# Notify managers in specific city
city = "New York"
User.manager.in_city(city).each do |manager|
  Notification.create(
    user: manager,
    message: "City-specific manager notification"
  )
end
```

### 3. Complex Role-Based Logic

Based on the Announcement model pattern:

```ruby
def define_notification_recipients(notification_type)
  recipients = []
  
  case notification_type
  when 'technical_issue'
    recipients = User.software.exclude(User.current).to_a
  when 'maintenance_alert'
    recipients = User.technician.to_a
  when 'management_update'
    recipients = User.any_admin.to_a
  when 'department_announcement'
    recipients = User.in_department(current_user.department_id).to_a
  when 'urgent_system_alert'
    recipients = User.superadmins.to_a
  when 'media_request'
    recipients = User.media.to_a
  when 'marketing_campaign'
    recipients = User.marketing.to_a
  else
    recipients = []
  end
  
  recipients.uniq
end

# Usage
recipients = define_notification_recipients('technical_issue')
recipients.each do |recipient|
  notification = Notification.create(
    user: recipient,
    message: "Technical issue notification",
    url: "/technical_issues/#{issue.id}"
  )
  UserNotificationChannel.broadcast_to(notification.user, notification)
end
```

### 4. Advanced Role Checking

```ruby
# Check if user has specific role
user.superadmin?  # true/false
user.admin?       # true/false
user.any_admin?   # true/false
user.technician?  # true/false
user.software?    # true/false
user.media?       # true/false
user.manager?     # true/false

# Conditional notification creation
if user.superadmin?
  Notification.create(
    user: user,
    message: "Superadmin-only notification"
  )
end
```

## Real-Time Notifications

### ActionCable Integration

The system uses ActionCable for real-time notification delivery:

```ruby
# UserNotificationChannel
class UserNotificationChannel < ApplicationCable::Channel
  def self.broadcast_to(user, notification)
    rendered_n = ApplicationController.render(
      partial: 'notifications/short_notification', 
      locals: { notification: notification }
    )
    ActionCable.server.broadcast("user_#{user.id}_notifications", rendered_n)
  end

  def subscribed
    stream_from "user_#{current_user.id}_notifications"
  end
end
```

### JavaScript Client-Side

```javascript
// app/assets/javascripts/channels/user_notification.js
App.cable.subscriptions.create({channel: 'UserNotificationChannel'}, {
  received(data) {
    if (!document.querySelector('#user_notifications').classList.contains('active-notifications')) {
      document.querySelector('#user_notifications').classList.add('active-notifications');
    }
    let notificationsContent = document.querySelector('#user_notifications').getAttribute('data-content');
    if (notificationsContent == null) {
      notificationsContent = '';
    }
    document.querySelector('#user_notifications').setAttribute('data-content', notificationsContent + data);
    document.querySelector('#user_notifications').click();
  }
})
```

## Authorization and Security

### Pundit Policy

```ruby
# app/policies/notification_policy.rb
class NotificationPolicy < BasePolicy
  def view_notifications?
    owner? || superadmin?
  end

  def close?
    view_notifications?
  end

  private

  def owner?
    user.id == record.user_id
  end
end
```

### Controller Authorization

```ruby
# app/controllers/notifications_controller.rb
class NotificationsController < ApplicationController
  before_action :set_notification, only: %i[destroy, close]

  def user_notifications
    authorize Notification
    @notifications = current_user.notifications.not_closed.page(params[:page])
    respond_to(&:js)
  end

  def close
    authorize @notification
    @notification.close
    respond_to(&:js)
  end

  private

  def set_notification
    @notification = Notification.find(params[:id])
  end
end
```

## Email Integration

For important notifications, combine in-app notifications with email:

```ruby
# app/mailers/service_jobs_mailer.rb
def staff_notice(service_job_id, user_id, details={})
  @service_job = ServiceJob.find(service_job_id).decorate
  @user = User.find(user_id)
  @details = details
  
  # Get subscribers' emails
  subcribers_emails = @service_job.subscribers.pluck(:email).compact
  
  if subcribers_emails.any?
    mail(
      to: subcribers_emails, 
      subject: I18n.t('service_jobs_mailer.staff_notice.subject', device: @service_job.device_name)
    )
  end
end
```

## Best Practices

### 1. Always Use Real-Time Broadcasting

```ruby
# After creating notification
notification = Notification.create(...)
UserNotificationChannel.broadcast_to(notification.user, notification)
```

### 2. Use Polymorphic Associations

Link notifications to related objects for better context:

```ruby
notification = Notification.create(
  user: user,
  message: "Your repair is complete",
  url: service_job_path(service_job),
  referenceable: service_job  # Links to ServiceJob model
)
```

### 3. Implement the Three-Method Pattern

For any model that needs to send notifications:

```ruby
def notification_recipients
  # Return users who should be notified
end

def notification_message
  # Return the notification message
end

def url
  # Return the relevant URL
end
```

### 4. Handle Notification Cleanup

```ruby
# Close notifications programmatically
notification.close

# Check if notification is closed
notification.closed?

# Query only open notifications
user.notifications.not_closed
```

### 5. Combine Role and Department Filtering

```ruby
# Notify all managers in specific departments
department_ids = [1, 2, 3]
User.manager.where(department_id: department_ids).each do |manager|
  Notification.create(
    user: manager,
    message: "Multi-department manager notification"
  )
end
```

## Routes

```ruby
resources :notifications, only: %i[destroy], defaults: { format: :js } do
  get :user_notifications, on: :collection, defaults: { format: :js }
  post :close, on: :member, defaults: { format: :js }
end
```

## Common Use Cases

### 1. System Maintenance Notifications

```ruby
# Notify all active staff about system maintenance
User.staff.each do |user|
  Notification.create(
    user: user,
    message: "System maintenance scheduled for #{maintenance_time}",
    url: "/maintenance"
  )
end
```

### 2. Task Assignment Notifications

```ruby
# Notify specific user about task assignment
notification = Notification.create(
  user: assigned_user,
  message: "You have been assigned to task: #{task.title}",
  url: task_path(task),
  referenceable: task
)
UserNotificationChannel.broadcast_to(notification.user, notification)
```

### 3. Approval Workflow Notifications

```ruby
# Notify managers when approval is needed
User.manager.in_department(request.department_id).each do |manager|
  Notification.create(
    user: manager,
    message: "Approval required for #{request.title}",
    url: request_path(request),
    referenceable: request
  )
end
```

This comprehensive guide provides all the necessary information to implement custom notifications and role-based filtering in the iTechService application. The system is flexible, secure, and supports real-time delivery with proper authorization controls.