FactoryBot.define do
  factory :agent_execution do
    agent { nil }
    status { "MyString" }
    input { "MyText" }
    output { "MyText" }
    execution_time { 1 }
  end
end
