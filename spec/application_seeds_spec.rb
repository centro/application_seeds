require 'application_seeds'

class Person
  attr_accessor :attributes, :id, :saved
  attr_accessor :first_name, :last_name, :company_id, :start_date

  def save!(options={})
    @saved = true
  end
end

class Company
  attr_accessor :attributes, :id, :saved
  attr_accessor :name

  def save!(options={})
    @saved = true
  end
end

class Department
  attr_accessor :attributes, :id, :saved
  attr_accessor :name

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
      expect(ApplicationSeeds.data_gem_name).to eql("application_seed_data")
    end
  end

  describe "#data_directory" do
    it "is able to set the data directory successfully" do
      expect(ApplicationSeeds.data_directory).to eql(File.join(File.dirname(__FILE__), "seed_data"))
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
        expect(ApplicationSeeds.instance_variable_get(:@dataset)).to eql("test_data_set")
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
      expect(ApplicationSeeds.dataset).to eql("test_data_set")
    end
  end

  describe "#seed_data_exists?" do
    it "returns true if the specified seed data exists" do
      expect(ApplicationSeeds.seed_data_exists?(:people)).to be_true
    end
    it "returns false if the specified seed data does not exist" do
      expect(ApplicationSeeds.seed_data_exists?(:missing)).to_not be_true
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
        expect(@object.id).to eql(636095969)
      end
      it "assigns the attributes" do
        expect(@object.attributes).to eql(@attributes.reject { |k,v| k == "bogus_attribute" })
      end
      it "saves the object in the database" do
        expect(@object.saved).to be_true
      end
    end

    describe "fetching all seed data" do
      before do
        @people = ApplicationSeeds.people
      end
      it "returns all people" do
        expect(@people.size).to eql(5)
      end
      it "returns the attributes for each person" do
        person = @people.values.sort { |a,b| b['start_date'] <=> a['start_date'] }[1]
        expect(person['first_name']).to eql("Jane")
        expect(person['last_name']).to eql("Doe")
      end
    end

    describe "fetching seed data by label" do
      it "returns the attributes for each person" do
        person = ApplicationSeeds.people(:jane_doe)
        expect(person['first_name']).to eql("Jane")
        expect(person['last_name']).to eql("Doe")
      end
      it "raises an error if no data could be found with the specified label" do
        expect { ApplicationSeeds.people(:bogus) }.to raise_error(RuntimeError)
      end
    end

    describe "fetching seed data by id" do
      it "can find the seed with an integer id" do
        person = ApplicationSeeds.people(487117267)
        expect(person['id']).to eql(487117267)
        expect(person['first_name']).to eql("Jane")
        expect(person['last_name']).to eql("Doe")
      end
      it "can find the seed with an string id" do
        person = ApplicationSeeds.people("487117267")
        expect(person['id']).to eql(487117267)
        expect(person['first_name']).to eql("Jane")
        expect(person['last_name']).to eql("Doe")
      end
      it "raises an error if no data could be found with the specified id" do
        expect { ApplicationSeeds.people(404) }.to raise_error(RuntimeError)
      end
    end

    describe "fetching seed data by property values" do
      it "returns the found person" do
        people = ApplicationSeeds.people(:last_name => 'Walsh', :company_id => :ma_and_pa)
        expect(people.size).to eql(1)
        expect(people.values.first['first_name']).to eql("John")
        expect(people.values.first['last_name']).to eql("Walsh")
      end
      it "returns multiple people if there are multiple matches" do
        people = ApplicationSeeds.people(:company_id => :mega_corp)
        expect(people.size).to eql(2)
        expect(people.values.first['first_name']).to eql("Joe")
        expect(people.values.last['first_name']).to eql("Jane")
      end
      it "can find elements using the id instead of the label" do
        people = ApplicationSeeds.people(:last_name => 'Walsh', :company_id => 47393448)
        expect(people.size).to eql(1)
        expect(people.values.first['first_name']).to eql("John")
        expect(people.values.first['last_name']).to eql("Walsh")
      end
      it "returns an empty hash if no matches could be found" do
        people = ApplicationSeeds.people(:last_name => '404')
        expect(people).to eql({})
      end
    end

    describe "specifying ids" do
      it "can fetch people by their specified id" do
        person = ApplicationSeeds.people(456)
        expect(person['id']).to eql(456)
        expect(person['first_name']).to eql("Sam")
        expect(person['last_name']).to eql("Jones")
        expect(person['company_id']).to eql(123)
      end
    end

    describe "ERB" do
      it "processes ERB snippets in the fixtures" do
        person = ApplicationSeeds.people(:joe_smith)
        expect(person['start_date']).to eql(2.months.ago.to_date)
      end
    end

    describe "when specifying the seed data type in the seed data file" do
      it "should look for the seed data in the specified type file" do
        person = ApplicationSeeds.people(:ken_adams)
        expect(person['employer_id']).to eql(47393448)
      end
    end

    describe "for attributes containing arrays of labels" do
      describe "when the target data type matches the attribute name" do
        it "builds the array of ids" do
          department = ApplicationSeeds.departments(:engineering)
          expect(department['people_ids']).to eql([636095969, 487117267, 10284664])
        end
      end
      describe "when specifying the seed data type in the seed data file" do
        it "should look for the seed data in the specified type file" do
          department = ApplicationSeeds.departments(:sales)
          expect(department['employee_ids']).to eql([456, 420015031])
        end
      end
    end
  end

  describe "with a nested dataset" do
    before do
      ApplicationSeeds.stub(:store_dataset)
      ApplicationSeeds.dataset = "level_3"
    end

    describe "finding seed data" do
      it "can find data at the root level" do
        company = ApplicationSeeds.companies(:mega_corp)
        expect(company['name']).to eql("Megacorp")
      end
      it "can find data at the middle level" do
        department = ApplicationSeeds.departments(:engineering)
        expect(department['name']).to eql("Engineering")
      end
      it "can find data at the lowest level" do
        person = ApplicationSeeds.people(:joe_smith)
        expect(person['first_name']).to eql("Joe")
      end
      it "can merge data from different levels" do
        person = ApplicationSeeds.people(:joe_smith)
        expect(person['first_name']).to eql("Joe")
        person = ApplicationSeeds.people(:sam_jones)
        expect(person['first_name']).to eql("Sam")
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
        expect(@person['id']).to eql("00000000-0000-0000-0000-000010284664")
        expect(@person['company_id']).to eql("00000000-0000-0000-0000-000047393448")
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
        expect(@person['id']).to eql("00000000-0000-0000-0000-000010284664")
        expect(@person['company_id']).to eql(47393448)
      end
    end
  end

end
