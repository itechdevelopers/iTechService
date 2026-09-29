# frozen_string_literal: true

require 'securerandom'

module Catalog
  # Explicit maintenance operation, never run from a request or an initializer.
  class RestoreIphone14OneSim
    GROUP_NAMES = ['iPhone 14', 'iPhone 14 Pro', 'iPhone 14 Pro Max'].freeze
    CAPACITIES = %w[128GB 256GB 512GB 1TB].freeze
    class Conflict < StandardError; end

    def call(apply: false)
      report = { apply: apply, groups: [] }
      Product.transaction do
        sim_type = OptionType.find_by!(name: 'Количество SIM')
        color_type = OptionType.find_by!(name: 'Цвет')
        capacity_type = OptionType.find_by!(name: 'Ёмкость')
        one_sim = sim_type.option_values.find_by!(name: '1 SIM')

        GROUP_NAMES.each do |name|
          groups = ProductGroup.devices.where(name: name).to_a
          raise Conflict, "Expected one equipment group: #{name}" unless groups.one?

          group = groups.first
          group.lock! if apply
          products = group.products.includes(:options).order(:id).to_a
          visible_ids = group.option_value_ids
          combinations = products.reject(&:archived?).group_by do |product|
            product.options.reject { |option| option.option_type_id == sim_type.id }.map(&:id).sort
          end
          result = { id: group.id, name: name, add_group_option: !visible_ids.include?(one_sim.id),
                     create: [], reuse: [] }
          combinations.each do |base_ids, variants|
            base = variants.first.options.reject { |option| option.option_type_id == sim_type.id }
            next unless base.map(&:option_type_id).sort == [color_type.id, capacity_type.id].sort

            capacity = base.find { |option| option.option_type_id == capacity_type.id }
            next unless CAPACITIES.include?(capacity.name)
            raise Conflict, "Hidden base options in #{name}: #{base_ids}" unless (base_ids - visible_ids).empty?

            ids = (base_ids + [one_sim.id]).sort
            matches = products.select { |product| product.option_ids.sort == ids }
            raise Conflict, "Duplicate or archived 1 SIM: #{name} #{base_ids}" if matches.size > 1 || matches.any?(&:archived?)

            if matches.one?
              product = matches.first
              verify_selection!(product, ids)
              result[:reuse] << product.id
              next
            end

            source = variants.min_by(&:id)
            color = base.find { |option| option.option_type_id == color_type.id }
            attributes = { name: "#{name} #{capacity.name} #{color.name} 1 SIM",
                           product_group_id: group.id, product_category_id: source.product_category_id,
                           warranty_term: source.warranty_term, article: nil, option_ids: ids }
            entry = { name: attributes[:name], source_id: source.id, option_ids: ids }
            if apply
              product = Product.create!(attributes.merge(code: unique_code))
              verify_selection!(product.reload, ids)
              entry.merge!(id: product.id, code: product.code)
            end
            result[:create] << entry
          end
          raise Conflict, "No selectable combinations in #{name}" if result[:create].empty? && result[:reuse].empty?

          if apply && result[:add_group_option]
            group.option_values << one_sim
          end
          report[:groups] << result
        end
      end
      report
    end

    private

    def verify_selection!(product, ids)
      unless Product.find_by_group_and_options(product.product_group_id, ids)&.id == product.id
        raise Conflict, "Product lookup is ambiguous: #{product.id}"
      end
    end

    def unique_code
      loop do
        code = (SecureRandom.random_number(90_000_000) + 10_000_000).to_s
        return code unless Product.unscoped.exists?(code: code)
      end
    end
  end
end
