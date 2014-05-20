# application_seeds

A library for managing a standardized set of seed data for applications
in a non-production environment.


## Requirements

* Rails
* Postgresql (This library currently only works with the Postgresql database)


## Usage

#### Include the gem in your Gemfile

    group :development do
      gem 'application_seeds'
    end

You should add this gem to any environment group that would need access
to the seed data (like an "integration" environment, for example).


#### Create a shared data set

This library operates on a set of YAML files that represent your shared
data set.  The dataset can be provided two different ways.

##### Via a gem

In order to easily share the seed data between apps, you can package
the YAML files into a gem.  The gem should have the following directory
structure:

```
lib/
 +-- seeds/
      |-- seed_data_set_1/
      |    |-- some_data.yml
      |    +-- some_other_data.yml
      +-- seed_data_set_2/
           |-- some_data.yml
           +-- some_other_data.yml
```

The gem may contain any number of datasets.  The above example has two datasets,
`seed_data_set_1` and `seed_data_set_2`.  The YAML files are located in the
dataset directories.

You will need to include the gem containing your seed data in your `Gemfile`.

Use the `data_gem_name` API method to specify where your seed data is located.

```ruby
ApplicationSeeds.data_gem_name = "my-seed-data-gem"
```

##### Via the filesystem

The dataset may also exist on the filesystem.  The directory structure should
be identical to what is described above in the "Via a gem" section, but the `lib`
diretory is not required.

```
seeds/
 |-- seed_data_set_1/
 |    |-- some_data.yml
 |    +-- some_other_data.yml
 +-- seed_data_set_2/
      |-- some_data.yml
      +-- some_other_data.yml
```

Use the `data_directory` API method to specify the path to your seed data on the filesystem.

```ruby
ApplicationSeeds.data_directory = "/path/to/seeds"
```

#### Create a rake task to create data model objects from the seed data

**The application** needs to create objects from the common seed data. To
do this, you will need to create a Rake task (such as the one
below) for your application that reads the seed data, and uses it to create the objects in
the application's own data model.

`ApplicationSeeds` provides an API to allow for the easy retrieveal of
seed data.  See below for more information about the API.

```ruby
namespace :application_seeds do
  desc 'Dump the development database and load it with standardized application seed data'
  task :load, [:dataset] => ['db:drop', 'db:create', 'db:migrate', :environment] do |t, args|
    ApplicationSeeds.data_gem_name = "my-seed-data-gem"
    ApplicationSeeds.dataset = args[:dataset]

    seed_campaigns
    seed_line_items
    seed_some_other_objects
  end

  def seed_campaigns
    # If we do not need to change the attirbute hash, we can just create
    # the object with the attributes that are specified in the seed data
    # file.
    ApplicationSeeds.campaigns.each do |id, attributes|
      ApplicationSeeds.create_object!(Campaign, id, attributes)
    end
  end

  def seed_line_items
    # If we need to reject attributes from the attribute hash, or
    # only use specific attributes, we can use the select_attributes or
    # the reject_attributes helper methods.
    ApplicationSeeds.line_items.each do |id, attributes|
      ApplicationSeeds.create_object!(LineItem, id, attributes.reject_attributes(:some_unused_attribute))
    end
  end

  def seed_some_objects
    # If we need to modify attribute names, we can do so using the
    # map_attributes helper method.
    ApplicationSeeds.some_objects.each do |id, attributes|
      ApplicationSeeds.create_object!(SomeObject, id, attributes.map_attributes(
        :old_name1 => :new_name1, :old_name2 => :new_name2))
    end
  end

  def seed_some_other_objects
    # If we need tighter control over how the object is created, we can
    # simply create it ourselves.
    ApplicationSeeds.some_other_objects.each do |id, attributes|
      x = SomeOtherObject.new(param1: attributes['param1'],
                              param2: attributes['param2'],
                              param3: attributes['param3'])
      x.id = id
      x.save!
    end
  end
end
```

#### Run the rake task

    bundle exec rake application_seeds:load[your_data_set]

You must specify the seed data set that you would like to use.  The dataset name is
simply the name of the directory containing the seed YAML files.


#### Or, run the capistrano task

Add the following line to your deploy.rb file:

    require "application_seeds/capistrano"

Then, you can seed a remote database by running the following:

    bundle exec cap <environment> deploy:application_seeds -s dataset=your_data_set


## The Datasets

The `application_seeds` library supports multiple datasets within the
same source (place on the file system, gem, etc).  The user specifies
which dataset to load when beginning to work with the seed data.

    ApplicationSeeds.dataset = "my_data_set"

### Nested Datasets

Datasets can be structured so that child directories can inherit the
seed data files that are stored in the parent directories.  For example,
let's look at the following directory structure:

```
seeds/
 +-- parent_data_set/
      |-- companies.yml
      +-- child_data_set/
          |-- departments.yml
          +-- grandchild_data_set/
              +-- people.yml
```

In this example, if the `grandchild_data_set` is loaded, you will have
access to the seed data files in `grandchild_data_set`,
`child_data_set`, and `parent_data_set`.  Because of this, data from
`people.yml`, `departments.yml`, and `companies.yml` can be loaded.

If `child_data_set` is loaded, you will have access to the seed data
files in `child_data_set` and `parent_data_set`, but **not**
`grandchild_data_set`.  This includes the `departments.yml` and
`companies.yml` data files.

### Merging Data Files

It is possible to have files for the same data type scattered throughout
the dataset hierarchy.

```
seeds/
 +-- parent_data_set/
      |-- companies.yml
      |-- people.yml
      +-- child_data_set/
          |-- departments.yml
          |-- people.yml
          +-- grandchild_data_set/
              +-- people.yml
```

In this example, when data is loaded from the `people` dataset via call
to `ApplicationSeeds.people`, then the result will contain the data from
all three files.

If the files contain conflicting labels, then precedence is given to
data at the lowest level (`grandchild_data_set` in this example).


## The Seed Files

The seed files contain the data that the Rake task works with to
populate the database.  The seed files look and work much like Rails
fixtures files.

Here is an example from the `people.yml` file in this library's test
suite:

```
joe_smith:
  first_name: Joe
  last_name: Smith
  company_id: mega_corp
  start_date: <%= 2.months.ago.to_date %>

jane_doe:
  first_name: Jane
  last_name: Doe
  company_id: mega_corp
  start_date: <%= 10.months.ago.to_date %>
```

Seed data must contain a label that is unique to the file.


### ERB

Seed files may contain ERB snippets to support more dynamic data, or
data that may change over time.


### Establishing relationships

Relationships can be established between seed data files using labels.
One piece of seed data can specify a `belongs_to` relationship with
another piece of seed data by specifying the other data's label in the
`_id` field.

In this example, `ApplicationSeeds` will look in the `companies.yml`
file for a seed data element with the label `mega_corp`.
```ruby
  company_id: mega_corp
```

If the `_id` field does not share a name with the file that the
corresponding seed data can be found, you can specify the name of the
seed file, like so:

```ruby
  employer_id: mega_corp (companies)
```


#### Many to Many

Many to many relationships can be specified using arrays.  The name of
the field must end in `ids` or `uuids`.

```ruby
  company_ids: [mega_corp, ma_and_pa]
```

If the `_ids` field does not share a name with the file that the
corresponding seed data can be found, you can specify the name of the
seed file, like so:

```ruby
  employer_ids: "[mega_corp, ma_and_pa] (companies)"
```

Here, the array must be enclosed in a string, to prevent the YAML parser
from erroring out due to invalid YAML syntax.


### Hard coding IDs

By default, `ApplicationSeeds` will generate a unique ID for each piece
of seed data based on the name of the file containing the data and the
data's label.  The IDs will not change, as long as the name of the file
containing the seed data and the labels do not change.

If you need to specify a specific id for a piece of seed data, you can
specify the id in the list of attributes.

```ruby
joe_smith:
  id: 123
  first_name: Joe
  last_name: Smith
  company_id: mega_corp
  start_date: <%= 2.months.ago.to_date %>
```

`ApplicationSeeds` will not generate an ID for you if one has been
specified.


### Examples

See `spec/seed_data/test_data_set` for more examples of seed data files.


## Config Values

Since the YAML files are first run through ERB, you are able to sprinkle
ruby code throughout your seed data files.  This allows you to do some
interesting things:

```ruby
<% 10.times do |x| %>
company_<%= x %>:
  name: Company_<%= x %>
<% end %>
```

But `10` here is a magic number.  It would be better if we had a
variable that better communicated its use.

`ApplicationSeeds` allows you to place a `_config.yml` file in each
dataset directory.  The data in this file is loaded, and made available
via the `ApplicationSeeds.config_value` API.

Take the following `_config.yml`:

```ruby
num_companies: 5
num_people: 1
num_departments: 3
```

You can fetch these values by calling `ApplicationSeeds.config_value`:

```ruby
ApplicationSeeds.config_value(:num_companies)
=> 5

ApplicationSeeds.config_value(:num_people)
=> 1

ApplicationSeeds.config_value(:num_departments)
=> 3
```

And use them in your seed files:

```ruby
<% ApplicationSeeds.config_value(:num_companies).times do |x| %>
company_<%= x %>:
  name: Company_<%= x %>
<% end %>
```


### Merging config value files

If you are using nested datasets, then all of the appropriate
`_config.yml` files will be loaded, and all data in those files
will be available. Config values defined in the lower levels
are given precedence if there is a naming conflict, allowing the
lower levels to override values specified in the upper levels.


## Configuration

The `ApplicationSeeds` module can generate integer or UUID ids.  You can
use the `config` method to tell `ApplicationSeeds` which id type you would
like to use.

ID types can be specified at the global level (to be applied to all seed data types)...
```ruby
ApplicationSeeds.config = { :id_type => :uuid }
```

...at  the data type level (if some types have UUID primary keys and other have integer primary keys)...
```ruby
ApplicationSeeds.config = { :people_id_type => :uuid, :companies_id_type => :integer }
```

...or a combination of both (if every type uses integer primary keys except for one, for example)
```ruby
ApplicationSeeds.config = { :id_type => :uuid, :companies_id_type => :integer }
```

`integer` is the default id type.

**`config` needs to be called before the dataset is specified using `dataset=`**


## The API

The `ApplicationSeeds` module provides an API that enables the programmatic retrieval of seed data,
so the rake task can easily access all the seed data necessary to build the data object.


### Specify the name of the directory containing the seed data

```ruby
ApplicationSeeds.data_directory = "/path/to/seeds/directory"
```

Specify the name of the directory that contains the application seed data.


### Specify the name of the gem containing the seed data

```ruby
ApplicationSeeds.data_gem_name = "my-seed-data-gem"
```

Specify the name of the gem that contains the application seed data.
Defaults to `application_seed_data` if this method is not called.


### Specify the dataset to be loaded

```ruby
ApplicationSeeds.dataset = "name_of_your_dataset"
```

Specify the name of the dataset to use.  An exception will be raised if
the dataset could not be found.


### Checking if a seed file exists in the dataset

```ruby
ApplicationSeeds.seed_data_exists?(:campaigns)
```

Returns `true` if `campaigns.yml` exists in this dataset, `false` if it
does not.


### Fetching all seeds of a given type

```ruby
ApplicationSeeds.campaigns  # where "campaigns" is the name of the seed file
```

This call returns a hash with one or more entries (depending on the contents of the seed file).
The IDs of the object are the keys, and a hash containing the object's attributes are the values.
An exception is raised if no seed data could be with the given name.


### Fetching seed data by label

```ruby
ApplicationSeeds.campaigns(:some_campaign)  # where "campaigns" is the name of the seed file, and :some_campaign is the label of the campaign
```

This call returns a hash containing the object's attributes.  An exception is raised if no
seed data could be found with the given label.


### Fetching seed data by ID

```ruby
ApplicationSeeds.campaigns(1)  # where "campaigns" is the name of the seed file, and 1 is the ID of the campaign
```

This call returns a hash containing the object's attributes.  An exception is raised if no
seed data could be found with the given ID.


### Fetching seed data by some other attribute

```ruby
ApplicationSeeds.campaigns(foo: 'bar', name: 'John')  # where "campaigns" is the name of the seed file
```

This call returns the seed data that contains the specified attributes, and the specified attribute values.  It returns a hash with zero or more entries.  The IDs of the object are the keys of the hash, and a hash containing the object's attributes are the values. Any empty hash will be returned if no seed data could be found with the given attribute names and values.


### Accessing attributes

A seed datum is a hash of attributes (with indifferent access):

```ruby
campaign = ApplicationSeeds.campaigns(642)
campaign["description"] # => "Best pizza in Chicago"
campaign[:budget]       # => 10000
```

### Creating an object

```ruby
ApplicationSeeds.create_object!(Campaign, id, attributes)
```

This call will create a new instance of the `Campaign` class, with the
specified id and attributes.

### Rejecting specific attributes

```ruby
ApplicationSeeds.create_object!(Campaign, id, attributes.reject_attributes(:unused_attribute))
```

This call will create a new instance of the `Campaign` class without the
`unused_attribute` attribute.


### Selecting specific attributes

```ruby
ApplicationSeeds.create_object!(Campaign, id, attributes.select_attributes(:attribute1, :attribute2))
```

This call will create a new instance of the `Campaign` class with only the
`attribute1` and `attribute2` attributes.


### Mapping attribute names

```ruby
ApplicationSeeds.create_object!(Campaign, id, attributes.map_attributes(
  :old_name1 => :new_name1, :old_name2 => :new_name2))
```

This call will create a new instance of the `Campaign` class, using the
seed data for old_name1 as the attribute value for new_name1, and the
seed data for old_name2 as the attribute value for new_name2.  This
method let's you easly account for slight differences is attribute names
across applications.


### Fetching the label for a specific seed

```ruby
ApplicationSeeds.label_for_id(:people, 636095969)
```

This call will return the label (as a symbol) of the seed data entry
that corresponds to the given seed type and id.  ID or UUID may be used
to identify the seed data entry.  `nil` will be returned if no seed data
entry could be found with the specified ID.


### Reset id column sequence numbers

```ruby
ApplicationSeeds.reset_sequence_numbers
```

This method will reset the sequence numbers on id columns for all tables
in the database with an id column.  If you are having issues where you
are unable to insert new data into the databse after your dataset has
been imported, then this should correct them.


### Defer referential integrity checks

```ruby
ApplicationSeeds.defer_referential_integrity_checks do
  # Process some seed data
end
```

This method will defer the enforcement of foreign key contraints while
the block of code is being executed.  This is useful when creating
chunks of seed data that have are dependent on each other's existance.


### Fetch data from the `_config.yml` files

```ruby
ApplicationSeeds.config_value(:foo)
```

Fetch the value for the key named `foo` that is defined in the
`_config.yml` config values files.  Will return nil if no config value
could be found by that name.


## The Problem

Applications in a service oriented architecture (SOA) are often
interconnected.  One of the challenges with a SOA is that, since the
applications are (and must be to some extent) all interconnected, the
data sets used by the different applications must be *in sync*.

Applications will need to store keys to data in other applications that
can be used to fetch more detailed information from the services that
own that data.  In order for one application to lookup data owned by
another application, the key specified by the client must be in the server's
data set, along with the other data associated with the key that the
client is requesting.

Often, each application will have its own, siloed seed data, making
inter-app communication impossible.  In order to get all of the
application data in sync, developers will often resort to populating
their development databases with production data.  Production data on a
developer machine (*especially* a laptop) is bad business.  Do you want
to send the email to all of your customers telling them that their
sensitive data was on a stolen laptop?  I didn't think so.


## The Goal

The goal of this project is to create a common set of seed data that can
be used by all applications running in development.  Re-seeding
the applications in development with this shared seed data would put them
all "on the same page", preparing them for inter-app communication.

The seed data would be in a general format, not formatted to any
application's data model.  Each application will have a script that
mutates this seed data to confirm to its data model, and then persist it
to its database.


## FAQ

#### Why not just stub calls to the respective services?

Easier said than done :)  Yes, it would be fantastic if we could run an
application in isolation, and everything just works.  But maintaining
the stubs can be difficult.  Also, when you stub out service calls,
you're not really testing the inter-app communication process.  More importantly,
stubbing out the calls really only works for read-only APIs.  For APIs that
create or mutate data, stubbing isn't an ideal strategy.  What happens
when the app tries to fetch data that it just created/updated on a remote
service?  How will you see the data you created/updated?


#### Doesn't this mean that I need all applications running, all of the time?

Not really.  But, you will need to be running the applications that
service API calls for whatever it is that you are developing/testing.
This is where [POW](http://pow.cx/) comes in.  POW is a zero-config Rack
server for OSX.  After installing POW, your apps will be accessible via a
.dev url, like http://myapp.dev  No more remembering to
start an application before you use one of its services.  No more
remembering which applications run on which ports.  If your application
is not currently running, POW will start it automatically on the fly.


#### Sounds great, what's the catch?

Making it easier for our applications to talk to one another does have
some disadvantages.  One being that it makes it easier to
couple applications.  The goal of a service oriented
architecture is to prevent this.  With great power comes great
responsibility.  Carefully consider the trade offs any time you
introduce an API call to fetch data from a remote service.
