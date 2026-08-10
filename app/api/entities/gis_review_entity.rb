class Entities::GisReviewEntity < Grape::Entity
  expose :id
  expose :external_review_id
  expose :status
  expose :user_id
end
