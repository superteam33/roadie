FactoryBot.define do
  factory :epic do
    name { "MyString" }
    description { "MyText" }
    status { "MyString" }
    priority { "MyString" }
    project { nil }
  end
end
