# frozen_string_literal: true

module Bot
  # Serializes the same equipment ProductGroup tree used by the device UI.
  # ProductGroup.devices is the source of truth; no parallel device catalogue is
  # maintained by the Bot API.
  class DeviceHierarchyPresenter
    def initialize(groups)
      @groups = groups.to_a.select { |group| active?(group) }
    end

    def as_json(*)
      nodes = @groups.each_with_object({}) do |group, result|
        result[group.id] = {
          id: group.id.to_s,
          name: group.name.to_s.strip,
          parent_id: parent_id(group),
          active: active?(group),
          children: []
        }
      end

      # A filtered equipment scope can contain a leaf whose non-equipment
      # ancestor is intentionally absent. Such nodes are roots in this public
      # tree, so never expose a dangling parent reference.
      nodes.each_value do |node|
        node[:parent_id] = nil if node[:parent_id] && !nodes.key?(node[:parent_id].to_i)
      end

      nodes.each_value do |node|
        parent = nodes[node[:parent_id].to_i] if node[:parent_id]
        parent[:children] << node if parent
      end
      roots = nodes.values.reject { |node| node[:parent_id] && nodes.key?(node[:parent_id].to_i) }
      classify(nodes)
      { success: true, items: roots }
    end

    private

    def parent_id(group)
      ancestry = group.ancestry.to_s
      ancestry.empty? ? nil : ancestry.split('/').last
    end

    def active?(group)
      group.respond_to?(:archived?) ? !group.archived? : true
    end

    def classify(nodes)
      nodes.each_value do |node|
        node[:type] = node[:children].empty? ? 'device' : 'group'
        node[:children].sort_by! { |child| child[:name].to_s }
      end
    end
  end
end
