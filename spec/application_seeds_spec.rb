require 'application_seeds'

class Person
  attr_accessor :attributes, :id, :saved
  attr_accessor :first_name, :last_name, :company_id, :start_date

  def save!(options={})
    @saved = true
  end
end

describe "ApplicationSeeds" do
  before do
    ApplicationSeeds.data_directory = File.join(File.dirname(__FILE__), "seed_data")
  end

  describe "#data_gem_name=" do
    it "raises an error if no gem could be found with the specified name" do
      expect { ApplicationSeeds.data_gem_name = "foo" }.to raise_error(Gem::LoadError)
    end
    it "raises an error if the specified gem does not contain seed data" do
      expect { ApplicationSeeds.data_gem_name = "rspec" }.to raise_error(RuntimeError, /does not appear to contain application seed data/)
    end
  end

  describe "#data_gem_name" do
    it "defaults to 'application_seed_data'" do
      ApplicationSeeds.data_gem_name.should == "application_seed_data"
    end
  end

  describe "#data_directory" do
    it "is able to set the data directory successfully" do
      ApplicationSeeds.data_directory.should == File.join(File.dirname(__FILE__), "seed_data")
    end
    it "raises an error if a non-existant directory specified" do
      expect { ApplicationSeeds.data_directory = "/foo/bar" }.to raise_error
    end
  end

  describe "#dataset=" do
    context "when an invalid dataset is specified" do
      it "raises an error if a nil dataset is specified" do
        expect { ApplicationSeeds.dataset = nil }.to raise_error
      end
      it "raises an error if a blank dataset is specified" do
        expect { ApplicationSeeds.dataset = "  " }.to raise_error
      end
      it "raises an error if an unknown dataset is specified" do
        expect { ApplicationSeeds.dataset = "foo" }.to raise_error
      end
      it "lists the available datasets in the error message" do
        expect { ApplicationSeeds.dataset = nil }.to raise_error(RuntimeError, /Available datasets: test_data_set/)
      end
    end

    context "when a valid dataset is specified" do
      before do
        connection_dummy = double
        connection_dummy.should_receive(:exec).with("INSERT INTO application_seeds (dataset) VALUES ('test_data_set');")
        ApplicationSeeds::Database.should_receive(:create_metadata_table)
        ApplicationSeeds::Database.should_receive(:connection) { connection_dummy }
        ApplicationSeeds.dataset = "test_data_set"
      end
      it "sets the dataset" do
        ApplicationSeeds.instance_variable_get(:@dataset).should == "test_data_set"
      end
    end
  end

  describe "#dataset" do
    before do
      connection_dummy = double
      response_dummy = double(:getvalue => "test_data_set")
      connection_dummy.should_receive(:exec).with("SELECT dataset from application_seeds LIMIT 1;") { response_dummy }
      ApplicationSeeds::Database.should_receive(:connection) { connection_dummy }
    end
    it "fetches the dataset name from the database" do
      ApplicationSeeds.dataset.should == "test_data_set"
    end
  end

  describe "#seed_data_exists?" do
    it "returns true if the specified seed data exists" do
      ApplicationSeeds.seed_data_exists?(:people).should be_true
    end
    it "returns false if the specified seed data does not exist" do
      ApplicationSeeds.seed_data_exists?(:missing).should_not be_true
    end
  end

  context "with a valid dataset" do
    before do
      ApplicationSeeds.stub(:store_dataset)
      ApplicationSeeds.dataset = "test_data_set"
    end

    describe "#create_object" do
      before do
        @attributes = ApplicationSeeds.people(:joe_smith)
        @object = ApplicationSeeds.create_object!(Person, @attributes['id'], @attributes)
      end
      it "assigns the id" do
        @object.id.should == 1709837792
      end
      it "assigns the attributes" do
        @object.attributes.should == @attributes.reject { |k,v| k == "bogus_attribute" }
      end
      it "saves the object in the database" do
        @object.saved.should be_true
      end
    end

    describe "fetching all seed data" do
      before do
        @people = ApplicationSeeds.people
      end
      it "returns all people" do
        @people.size.should == 4
      end
      it "returns the attributes for each person" do
        person = @people.values.sort { |a,b| b['start_date'] <=> a['start_date'] }[1]
        person['first_name'].should == "Jane"
        person['last_name'].should == "Doe"
      end
    end

    describe "fetching seed data by label" do
      it "returns the attributes for each person" do
        @person = ApplicationSeeds.people(:jane_doe)
        @person['first_name'].should == "Jane"
        @person['last_name'].should == "Doe"
      end
      it "raises an error if no data could be found with the specified label" do
        expect { ApplicationSeeds.people(:bogus) }.to raise_error(RuntimeError)
      end
    end

    describe "fetching seed data by id" do
      it "can find the seed with an integer id" do
        @person = ApplicationSeeds.people(1560859090)
        @person['id'].should == 1560859090
        @person['first_name'].should == "Jane"
        @person['last_name'].should == "Doe"
      end
      it "can find the seed with an string id" do
        @person = ApplicationSeeds.people("1560859090")
        @person['id'].should == 1560859090
        @person['first_name'].should == "Jane"
        @person['last_name'].should == "Doe"
      end
      it "raises an error if no data could be found with the specified id" do
        expect { ApplicationSeeds.people(404) }.to raise_error(RuntimeError)
      end
    end

    describe "fetching seed data by property values" do
      it "returns the found person" do
        @people = ApplicationSeeds.people(:last_name => 'Walsh', :company_id => :ma_and_pa)
        @people.size.should == 1
        @people.values.first['first_name'].should == "John"
        @people.values.first['last_name'].should == "Walsh"
      end
      it "returns multiple people if there are multiple matches" do
        @people = ApplicationSeeds.people(:company_id => :mega_corp)
        @people.size.should == 2
        @people.values.first['first_name'].should == "Joe"
        @people.values.last['first_name'].should == "Jane"
      end
      it "can find elements using the id instead of the label" do
        @people = ApplicationSeeds.people(:last_name => 'Walsh', :company_id => 3268618917)
        @people.size.should == 1
        @people.values.first['first_name'].should == "John"
        @people.values.first['last_name'].should == "Walsh"
      end
      it "returns an empty hash if no matches could be found" do
        @people = ApplicationSeeds.people(:last_name => '404')
        @people.should == {}
      end
    end

    describe "specifying ids" do
      it "can fetch people by their specified id" do
        @person = ApplicationSeeds.people(456)
        @person['id'].should == 456
        @person['first_name'].should == "Sam"
        @person['last_name'].should == "Jones"
        @person['company_id'].should == 123
      end
    end

    describe "ERB" do
      it "processes ERB snippets in the fixtures" do
        @person = ApplicationSeeds.people(:joe_smith)
        @person['start_date'].should == 2.months.ago.to_date
      end
    end
  end

  describe "with UUIDs configured for all seed types" do
    before do
      ApplicationSeeds.stub(:store_dataset)
      ApplicationSeeds.config = { :id_type => :uuid }
      ApplicationSeeds.dataset = "test_data_set"
    end

    describe "when fetching seed data" do
      before do
        @person = ApplicationSeeds.people(:john_walsh)
      end
      it "uses UUIDs for the keys" do
        @person['id'].should == "00000000-0000-0000-0000-002157768310"
        @person['company_id'].should == "00000000-0000-0000-0000-003268618917"
      end
    end
  end

  describe "with data type specific key types configured" do
    before do
      ApplicationSeeds.stub(:store_dataset)
      ApplicationSeeds.config = { :id_type => :uuid, :companies_id_type => :integer }
      ApplicationSeeds.dataset = "test_data_set"
    end

    describe "when fetching seed data" do
      before do
        @person = ApplicationSeeds.people(:john_walsh)
      end
      it "uses UUIDs for the keys" do
        @person['id'].should == "00000000-0000-0000-0000-002157768310"
        @person['company_id'].should == 3268618917
      end
    end
  end

end
