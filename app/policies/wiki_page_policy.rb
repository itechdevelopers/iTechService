class WikiPagePolicy < CommonPolicy
  def manage?
    any_admin? || able_to?(:manage_wiki)
  end
  def search?
    read?
  end
  def wiki_senior?
    senior_manage?
  end
  def wiki_superadmin?
    superadmin?
  end
end
