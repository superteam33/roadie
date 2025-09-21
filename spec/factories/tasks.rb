FactoryBot.define do
  factory :task do
    title { "MyString" }
    description { "MyText" }
    status { "MyString" }
    priority { "MyString" }
    assignee { nil }
    epic { nil }
    project { nil }
  end
end
