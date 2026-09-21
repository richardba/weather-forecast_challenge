class Address
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :query, :string

  validates :query, presence: true
end
