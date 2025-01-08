# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.11'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
# Rails.application.config.assets.paths << Rails.root.join('node_modules')
Rails.application.config.assets.paths << Rails.root.join('vendor', 'assets', 'fonts', 'font-awesome')

# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in app/assets folder are already added.
Rails.application.config.assets.precompile += %w[auth.js auth.css]

Rails.application.config.assets.precompile += %w[
  ckeditor/*
  jquery-ui-1.9.1.custom.min.css
  jstree/apple/style.css
  datepicker.css
  bootstrap-datetimepicker.min.css
  customicons.css
  electronic_queue.css
  notifications/ticket_called.mp3
]

Rails.application.config.assets.precompile += %w[
  association_filter.js.coffee
  currency-in-words.js
  accounting.js
  bootstrap-datepicker.js
  bootstrap-datetimepicker.min.js
  bootstrap_select.min.js
  jquery.jstree.js
  electronic_queue.js
  tv_show.js.coffee
]

Rails.application.config.assets.precompile += %w[
  rails-ujs
  media_menu/application.css
  media_menu/application.js
  font-awesome/*
  media_menu/framework.css
  media_menu/framework.js
  jquery-2.2.4.min.js
  rating_bar/jquery.barrating.min.js
  review_page.js
  review.css
  popper.min.js
  tippy-bundle.umd.min.js
  rating_bar_static.css
  rating_bar_static.js
  sortablejs.min.js
]
