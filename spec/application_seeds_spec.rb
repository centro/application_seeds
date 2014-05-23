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
  let(:people) { ApplicationSeeds.people }

  let(:joe_smith_id) { 636095969 }
  let(:jane_doe_id) { 487117267 }
  let(:john_walsh_id) { 10284664 }
  let(:john_walsh_uuid) { "00000000-0000-0000-0000-000010284664" }
  let(:sam_jones_id) { 456 } # explicitly set in datafile
  let(:ken_adams_id) { 420015031 }
  let(:ma_and_pa_id) { 47393448 }
  let(:ma_and_pa_uuid) { "00000000-0000-0000-0000-000047393448" }

  let(:joe_smith) { ApplicationSeeds.people(:joe_smith) }
  let(:john_walsh) { ApplicationSeeds.people(:john_walsh) }
  let(:sam_jones) { ApplicationSeeds.people(:sam_jones) }
  let(:jane_doe) { ApplicationSeeds.people(:jane_doe) }

  # FIXME: the id is not injected into the attributes when the whole dataset is returned
  # when this bug is fixed, get rid of the `_without_id` definitions here and replace
  # their uses
  let(:joe_smith_without_id) { joe_smith.reject_attributes(:id) }
  let(:john_walsh_without_id) { john_walsh.reject_attributes(:id) }
  let(:sam_jones_without_id) { sam_jones.reject_attributes(:id) }
  let(:jane_doe_without_id) { jane_doe.reject_attributes(:id) }

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
        ApplicationSeeds.dataset = "test_data_set"
      end
      it "sets the dataset" do
        expect(ApplicationSeeds.instance_variable_get(:@dataset)).to eql("test_data_set")
      end
    end
  end

  context "with a valid dataset" do
    before do
      ApplicationSeeds.dataset = "test_data_set"
    end

    describe "#seed_data_exists?" do
      it "returns true if the specified seed data exists" do
        expect(ApplicationSeeds.seed_data_exists?(:people)).to be_true
        expect(ApplicationSeeds.seed_data_exists?(:companies)).to be_true
        expect(ApplicationSeeds.seed_data_exists?(:departments)).to be_true
      end
      it "returns false if the specified seed data does not exist" do
        expect(ApplicationSeeds.seed_data_exists?(:missing)).to_not be_true
      end
    end

    describe "#create_object" do
      let(:object) { ApplicationSeeds.create_object!(Person, joe_smith['id'], joe_smith) }
      it "assigns the id" do
        expect(object.id).to eql(joe_smith_id)
      end
      it "assigns the attributes" do
        expect(object.attributes).to eql(joe_smith.reject_attributes("bogus_attribute"))
      end
      it "saves the object in the database" do
        expect(object.saved).to be_true
      end
    end

    describe "fetching all seed data" do
      it "returns all people" do
        expect(people.size).to eql(5)
      end
      it "uses a computed id as the key" do
        expect(people[joe_smith_id]).to eql(joe_smith_without_id)
      end
      it "uses the id from the object's attributes as the key" do
        expect(people[sam_jones_id]).to eql(sam_jones)
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
        expect(ApplicationSeeds.people(jane_doe_id)).to eql(jane_doe)
      end
      it "can find the seed with an string id" do
        expect(ApplicationSeeds.people(jane_doe_id.to_s)).to eql(jane_doe)
      end
      it "raises an error if no data could be found with the specified id" do
        expect { ApplicationSeeds.people(404) }.to raise_error(RuntimeError)
      end
    end

    describe "fetching seed data by property values" do
      it "returns the found person" do
        people = ApplicationSeeds.people(:last_name => 'Walsh', :company_id => :ma_and_pa)
        expect(people.values).to match_array([john_walsh_without_id])
      end
      it "returns multiple people if there are multiple matches" do
        people = ApplicationSeeds.people(:company_id => :mega_corp)
        expect(people.values).to match_array([joe_smith_without_id, jane_doe_without_id])
      end
      it "can find elements using the id instead of the label" do
        people = ApplicationSeeds.people(:last_name => 'Walsh', :company_id => 47393448)
        expect(people.values).to match_array([john_walsh_without_id])
      end
      it "returns an empty hash if no matches could be found" do
        people = ApplicationSeeds.people(:last_name => '404')
        expect(people).to be_empty
      end
    end

    describe "specifying ids" do
      it "can fetch people by their specified id" do
        person = ApplicationSeeds.people(456)
        expect(person).to eql(sam_jones)
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
        expect(person['employer_id']).to eql(ma_and_pa_id)
      end
    end

    describe "for attributes containing arrays of labels" do
      describe "when the target data type matches the attribute name" do
        it "builds the array of ids" do
          department = ApplicationSeeds.departments(:engineering)
          expect(department['people_ids']).to eql([joe_smith_id, jane_doe_id, john_walsh_id])
        end
      end
      describe "when specifying the seed data type in the seed data file" do
        it "should look for the seed data in the specified type file" do
          department = ApplicationSeeds.departments(:sales)
          expect(department['employee_ids']).to eql([sam_jones_id, ken_adams_id])
        end
      end
    end

    describe "config values" do
      it "can fetch config values for the dataset" do
        expect(ApplicationSeeds.config_value(:num_companies)).to eql(15)
        expect(ApplicationSeeds.config_value(:num_people)).to eql(100)
      end
      it "returns nil if no config value could be found by that name" do
        expect(ApplicationSeeds.config_value(:whaa)).to be_nil
      end
    end

    describe "fetching the label for an id" do
      it "can fetch the label for a given id" do
        expect(ApplicationSeeds.label_for_id(:people, joe_smith_id)).to eql(:joe_smith)
      end
      it "returns nil if the id could not be found" do
        expect(ApplicationSeeds.label_for_id(:people, 111111111)).to be_nil
      end
    end
  end

  describe "with a nested dataset" do
    before do
      ApplicationSeeds.dataset = "level_3"
    end

    describe "#seed_data_exists?" do
      it "returns true if the specified seed data exists" do
        expect(ApplicationSeeds.seed_data_exists?(:people)).to be_true
        expect(ApplicationSeeds.seed_data_exists?(:companies)).to be_true
        expect(ApplicationSeeds.seed_data_exists?(:departments)).to be_true
      end
      it "returns false if the specified seed data does not exist" do
        expect(ApplicationSeeds.seed_data_exists?(:missing)).to_not be_true
      end
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
    end

    describe "merging seed data" do
      it "can merge data from different levels" do
        person = ApplicationSeeds.people(:joe_smith)
        expect(person['first_name']).to eql("Joe")
        person = ApplicationSeeds.people(:sam_jones)
        expect(person['first_name']).to eql("Sam")
      end
      it "gives the data in lower levels precedence" do
        person = ApplicationSeeds.people(:ken_adams)
        expect(person['first_name']).to eql("Ken")
      end
    end

    describe "merging config values" do
      it "can merge data from different levels" do
        expect(ApplicationSeeds.config_value(:num_companies)).to eql(5)
        expect(ApplicationSeeds.config_value(:num_departments)).to eql(3)
      end
      it "gives the data in lower levels precedence" do
        expect(ApplicationSeeds.config_value(:num_people)).to eql(10)
      end
    end
  end

  describe "with UUIDs configured for all seed types" do
    before do
      ApplicationSeeds.reset!
      ApplicationSeeds.config  = { :id_type => :uuid }
      ApplicationSeeds.dataset = "test_data_set"
    end

    describe "when fetching seed data" do
      it "uses UUIDs for the keys" do
        expect(john_walsh['id']).to eql(john_walsh_uuid)
        expect(john_walsh['company_id']).to eql(ma_and_pa_uuid)
      end
    end

    describe "fetching the label for an uuid" do
      it "can fetch the label for a given uuid" do
        expect(ApplicationSeeds.label_for_id(:people, john_walsh_uuid)).to eql(:john_walsh)
      end
      it "returns nil if the uuid could not be found" do
        expect(ApplicationSeeds.label_for_id(:people, '00000000-0000-0000-0000-000011111111')).to be_nil
      end
    end
  end

  describe "with data type specific key types configured" do
    before do
      ApplicationSeeds.reset!
      ApplicationSeeds.config  = { :id_type => :uuid, :companies_id_type => :integer }
      ApplicationSeeds.dataset = "test_data_set"
    end

    describe "when fetching seed data" do
      it "uses UUIDs for the keys" do
        expect(john_walsh['id']).to eql(john_walsh_uuid)
        expect(john_walsh['company_id']).to eql(ma_and_pa_id)
      end
    end
  end
end
