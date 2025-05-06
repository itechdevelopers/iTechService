#frozen_string_literal: true

class ProductFinderService < OneCBaseClient
  def self.call(**args)
    new.find_by_article(args[:article])
  end

  def find_by_article(article)
    #TODO: сделать в обратном порядке
    find_by_database(article) || find_by_1c(article)
  end

  private

  def find_by_1c(article)
    {
      status: 'found',
      price: '100',
      name: 'ЗАГЛУШКА ДЛЯ ТЕСТА iPhone 16 Pro Desert Titanium 128GB',
      kind: 'device',
      stores: [
        {
          id: '6',
          name: 'Дефолт подразделение запчасти',
          quantity: '15'
        },
        {
          id: '5',
          name: 'Дефолт подразделение ритэйл',
          quantity: '0'
        }
      ]
    }
  rescue => e
    Rails.logger.warn("Got an error while finding product info by 1C: #{e.message}")
    nil
  end

  def find_by_database(article)
    product = Product.find_by(article: article)

    if product
      {
        status: 'found',
        name: product.name,
        kind: product.object_kind_for_order
      }
    end
  end
end
