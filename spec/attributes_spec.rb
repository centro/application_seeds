require 'application_seeds'

describe "Attributes" do
  before do
    @attributes = ApplicationSeeds::Attributes.new("first_name" => "Billy",
                                                   "last_name"  => "Bob",
                                                   "occupation" => "Bus Driver",
                                                   major_house: "Atreides")
  end

  describe "attribute access" do
    it "works with a string key" do
      expect(@attributes["first_name"]).to eq("Billy")
      expect(@attributes["major_house"]).to eq("Atreides")
    end
    it "works with a symbol key" do
      expect(@attributes[:first_name]).to eq("Billy")
      expect(@attributes[:major_house]).to eq("Atreides")
    end
  end

  describe "#select_attributes" do
    before do
      @selected_attributes = @attributes.select_attributes(:first_name, "occupation")
    end
    it "returns only the select attributes" do
      expect(@selected_attributes).to eql({ "first_name" => "Billy", "occupation" => "Bus Driver" })
    end
    it "returns a new instance of the Attributes class" do
      expect(@selected_attributes).to be_a(ApplicationSeeds::Attributes)
    end
  end

  describe "#reject_attributes" do
    before do
      @rejected_attributes = @attributes.reject_attributes(:first_name, :last_name, "major_house")
    end
    it "returns only the select attributes" do
      expect(@rejected_attributes).to eql({ "occupation" => "Bus Driver" })
    end
    it "returns a new instance of the Attributes class" do
      expect(@rejected_attributes).to be_a(ApplicationSeeds::Attributes)
    end
  end

  describe "#map_attributes" do
    before do
      @mapped_attributes = @attributes.map_attributes(:first_name => :fname, 'last_name' => 'lname')
    end
    it "uses the new keys" do
      expect(@mapped_attributes).to eql({ "fname" => "Billy", "lname" => "Bob", "occupation" => "Bus Driver", "major_house" => "Atreides" })
    end
    it "returns a new instance of the Attributes class" do
      expect(@mapped_attributes).to be_a(ApplicationSeeds::Attributes)
    end
  end
end
