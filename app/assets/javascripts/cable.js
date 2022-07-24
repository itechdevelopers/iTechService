//= require action_cable
//= require_self
//= require_tree ./channels

(function() {
  App.cable = ActionCable.createConsumer()
}).call(this)