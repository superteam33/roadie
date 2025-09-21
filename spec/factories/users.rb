FactoryBot.define do
  factory :user do
    name { "MyString" }
    email { "MyString" }
    password_digest { "MyString" }
    role { "MyString" }
    integration_tokens { "MyText" }
  end
end
