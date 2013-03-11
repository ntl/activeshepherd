# WARNING: DANGER AHEAD!

*This repo is titled "eat-my-babies" for a reason. It's essentially scratch code at this point.*

# ActiveShepherd

Is your app/models directory growing unweildy? Do you find yourself desiring the notion of aggregates to help corral your less important models under the umbrella of more important "business entities?" That's the problem I had that led me to write this gem. I wanted to be able to reason about an entire namespace of models as one thing; or an "aggregate" in enterprisey development parlance.

My main goal was to be able to keep using ActiveRecord and intrude on it as little as possible. The result was an approach that requires you to wire up your models a bit more strictly -- you need to be setting options like `dependent: 'destroy'`, `autosave: true`, and `inverse_of` on all associations to the sub objects. The benefit you get from this gem is to be able to both query and manipulate the state of the entire aggregate all at once.

There are more requirements that are outlined by Eric Evans in his brilliant Domain Driven Design book, whose self titled concept is still very new to me.

## Installation

Add this line to your application's Gemfile:

    gem 'activeshepherd'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install activeshepherd

In your `config/initializers` directory, add a tiny shim into ActiveRecord::Base:

    ActiveShepherd.enable!(ActiveRecord::Base)

## Usage

1. Pick a model you'd like to make into an aggregate root
2. Add `act_as_aggregate_root!` to the model, e.g.:
     end
3. Make sure it follows the rules (e.g. [see this blog post](http://lostechies.com/jimmybogard/2008/05/21/entities-value-objects-aggregates-and-roots/))
4. ??
5. Profit!

## Examples:

See the test suite for more fleshed out examples. For now, say you have two models:

```ruby
# app/models/my_model.rb
class MyModel < ActiveRecord::Base
  act_as_aggregate_root!

  has_many :bunnies, autosave: true, dependent: :destroy, inverse_of: :my_model,
    validate: true
end

# app/models/my_model/bunny.rb
class MyModel::Bunny < ActiveRecord::Base
  belongs_to :my_model, inverse_of: :bunnies, touch: true
end
```
<!-- ` -->

Now add a test to make sure your models always meet the requirements for being an aggregate root:

```ruby
# spec/models/my_model_spec.rb
describe MyModel do
  it "is an aggregate root" do
    MyModel.should be_able_to_act_as_aggregate_root
  end
end

# test/unit/my_model_test.rb
class MyModel::TestCase < Minitest::Unit::TestCase
  def test_should_be_aggregate_root
    assert MyModel.able_to_act_as_aggregate_root?
  end
end
```
<!-- ` -->

You now get some new behavior on MyModel that will let you deal with the entire aggregate nicely:

```ruby
>> @my_model = MyModel.new
>> @my_model.bunnies.build({ name: "Roger"})
>> @my_model.save

# Nothing new, right? wrong.

>> @my_model.aggregate_state
=> {
     bunnies: [
       { name: "Roger" }
     ]
   }

# Sweet, what about changes?

>> @my_model.bunnies.first.name = "Roger Rabbit"
>> @my_model.bunnies.build({ name: "Energizer" })

# BAM!

>> @my_model.aggregate_changes
=> {
     bunnies: {
       0 => { name: ["Roger", "Roger Rabbit"] },
       1 => { name: [nil, "Energizer"] }
     }
  }
```
<!-- ` -->

So `#aggregate_changes` is just like ActiveRecord's `#changes`, except it includes all of the nested changes within the aggregate.

That's a brief description of what this gem does. Here are the main methods that `acts_as_aggregate_root!` brings to your ActiveRecord models:

| Method name           | Description                                                                        |
|:---------------------:|:----------------------------------------------------------------------------------:|
| `#aggregate_state`    | Serializes the entire state of the aggregate                                       |
| `#aggregate_state=`   | Takes a serialized blob and uses it to set the entire state of the aggregate       |
| `#aggregate_changes`  | Analagous to `#changes`; it tells you what all has changes in the entire aggregate |
| `#aggregate_changes=` | Takes an existing set of changes and applies it to the aggregate                   |

## Todo

This project is way alpha right now, hence the "eat-my-babies" project name.

1. Implement `ClassValidator` which will correctly tell you if a class can be an aggregate root (e.g. are your associations wired up correctly?)
2. Implement `ChangeValidator` that adds a little more niceness around `#aggregate_changes=`

My main goal right now is to use the code as it exists for a while and deal with problems as they arise. Consider the entire gem incomplete for right now.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
