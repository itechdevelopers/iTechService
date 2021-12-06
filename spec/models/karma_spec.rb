require 'rails_helper'

describe Karma do
  let(:karma) { create :karma }

  it 'is valid with valid attributes' do
    build(:karma).should be_valid
  end

  it 'is grouped with other karma' do
    let(:karma2) { create :karma }
    karma.group_with karma2
    karma.karma_group.should_not be_nil
    karma.karma_group.should eq karma2.karma_group
  end

  it 'can not be grouped with bad karma' do
    let(:karma2) { create :karma, :bad }
    karma.group_with karma2
    karma.karma_group.should be_nil
    karma2.karma_group.should be_nil
  end

  it 'is added to group' do
    let(:karma_group) { create :karma_group }
    karma.add_to_group karma_group
    karma.karma_group.should eq karma_group
  end

  it 'is ungrouped' do
    karma.create_karma_group
    karma.ungroup
    karma.karma_group.should be_nil
  end

  context 'bad' do
    let(:karma) { create :karma, :bad }

    it 'can not be grouped with other karma' do
      let(:karma2) { create :karma }
      karma.group_with karma2
      karma.karma_group.should be_nil
      karma2.karma_group.should be_nil
    end

    it 'can not be added to group' do
      let(:karma_group) { create :karma_group }
      karma.add_to_group karma_group
      karma.karma_group.should_not eq karma_group
    end
  end

end
