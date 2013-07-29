require 'application_seeds'

describe "Attributes" do
  before do
    @attributes = ApplicationSeeds::Attributes.new("first_name" => "Billy",
                                                   "last_name"  => "Bob",
                                                   "occupation" => "Bus Driver")
  end

  describe "#select_attributes" do
    before do
      @selected_attributes = @attributes.select_attributes(:first_name, :occupation)
    end
    it "returns only the select attributes" do
      @selected_attributes.should == { "first_name" => "Billy", "occupation" => "Bus Driver" }
    end
    it "returns a new instance of the Attributes class" do
      @selected_attributes.is_a?(ApplicationSeeds::Attributes).should be_true
    end
  end

  describe "#reject_attributes" do
    before do
      @rejected_attributes = @attributes.reject_attributes(:first_name, :last_name)
    end
    it "returns only the select attributes" do
      @rejected_attributes.should == { "occupation" => "Bus Driver" }
    end
    it "returns a new instance of the Attributes class" do
      @rejected_attributes.is_a?(ApplicationSeeds::Attributes).should be_true
    end
  end

  describe "#map_attributes" do
    before do
      @mapped_attributes = @attributes.map_attributes(:first_name => :fname, :last_name => :lname)
    end
    it "returns only the select attributes" do
      @mapped_attributes.should == { "fname" => "Billy", "lname" => "Bob", "occupation" => "Bus Driver" }
    end
    it "returns a new instance of the Attributes class" do
      @mapped_attributes.is_a?(ApplicationSeeds::Attributes).should be_true
    end
  end
end
