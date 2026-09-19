require "test_helper"

class AddressQueryTest < ActiveSupport::TestCase
  test "valid with an address" do
    assert AddressQuery.new(address: "1 Infinite Loop, Cupertino, CA").valid?
  end

  test "invalid when blank or whitespace only" do
    [nil, "", "   "].each do |input|
      query = AddressQuery.new(address: input)
      assert_not query.valid?, "expected #{input.inspect} to be invalid"
      assert_includes query.errors[:address], "can't be blank"
    end
  end

  test "invalid when too long" do
    query = AddressQuery.new(address: "a" * (AddressQuery::MAX_LENGTH + 1))
    assert_not query.valid?
  end

  test "normalizes whitespace" do
    query = AddressQuery.new(address: "  1 Infinite   Loop \n Cupertino ")
    assert_equal "1 Infinite Loop Cupertino", query.address
  end
end