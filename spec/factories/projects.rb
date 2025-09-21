FactoryBot.define do
  factory :project do
    name { "MyString" }
    description { "MyText" }
    status { "MyString" }
    owner { nil }
  end
end
