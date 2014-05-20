v0.9.1, 2014-05-20
------------------

  * Correct a date in this CHANGELOG.


v0.9.0, 2014-05-20
------------------

  * Use hashes with indifferent access for the attributes.


v0.8.0, 2014-05-16
------------------

  * Added the `ApplicationSeeds.label_for_id` method.


v0.7.0, 2014-05-02
------------------

  * Stop storing the dataset in the database.  Removed the
    `ApplicationSeeds.dataset` method.


v0.6.0, 2014-03-06
------------------

  * Added method that will allow the user to defer the enforcement of
    referential integrity checks while a block of code is being
    executed.


v0.5.0, 2014-02-28
------------------

  * Added support for config values.


v0.4.3, 2014-02-22
------------------

  * Only parse the seed data files once.


v0.4.2, 2014-02-18
------------------

  * Fixed `seed_data_exists?` to work with new nested/inheritable
    datasets


v0.4.1, 2014-02-14
------------------

  * Moved code that tells Rails schema dump to ignore the
    application_seeds table to lib/application_seeds.rb


v0.4.0, 2014-02-09
------------------

  * Added support for nested/inheritable datasets
  * Warn user if `ApplicationSeeds.config=` is called after `ApplicationSeeds.dataset=`


v0.3.0, 2014-01-09
------------------

  * Added support for Capistrano 3.x


v0.2.0, 2013-12-27
------------------

  * Changed the seed data file format from a YAML Array to a YAML Hash
  * Added support for seed data labels
  * Added support for generated IDs
  * Added support for integer or UUID ids


v0.1.1, 2013-12-18
------------------

  * No change.  Redeployed to fix bad 0.1.0 rubygems push.


v0.1.0, 2013-12-13
------------------

  * Prevent the `application_seeds` table from showing up in a Rails
    project's `schema.rb` file.


v0.0.1, 2013-07-26
------------------

  * Initial release.

