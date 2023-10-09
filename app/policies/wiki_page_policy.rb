class WikiPagePolicy < CommonPolicy
  def manage?
    any_admin? || able_to?(:manage_wiki)
  end
  def search?
    read?
  end
end
