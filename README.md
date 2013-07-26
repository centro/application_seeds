# application_seeds

A library for managing a standardized set of seed data for applications
in a non-production environment.


## Requirements

* Postgresql - This library currently only works with the Postgresql
database.


## Usage

#### Include the gem in your Gemfile

    group :development, :test, :integration, :staging do
      gem 'application_seeds', :git => 'git@github.com:centro/application_seeds.git'
    end


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


### Determining the dataset that has been loaded

```ruby
ApplicationSeeds.dataset
```

Returns the name of the dataset that has been loaded, or nil if not
running an application_seeds dataset.


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

This call returns a hash with one or more entries (depending on the contentes of the seed file).
The IDs of the object are the keys, and a hash containing the object's attributes are the values.
An exception is raised if no seed data could be with the given name.


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

This call returns the seed data that contains the specified attributes,
and the specified attribute values.  It returns a hash with zero or more
entries.  The IDs of the object are the keys of the hash, and a hash
containing the object's attributes are the values.  Any empty hash will
be returned if no seed data could be found with the given attribute names
and values.


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


### Reset id column sequence numbers

```ruby
ApplicationSeeds.reset_sequence_numbers
```

This method will reset the sequence numbers on id columns for all tables
in the database with an id column.  If you are having issues where you
are unable to insert new data into the databse after your dataset has
been imported, then this should correct them.


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
