require_relative '../test_helper'

class AccessControlledTest < ActiveSupport::TestCase

  setup do 
    Lock.stubs(:lock_application).returns(true)
    Lock.stubs(:unlock_application).returns(true)
  end

  def test_member_equivalent
    assert_equal Member.new(_id: 'a'), Member.new(_id: 'a')
    assert_equal Member.new(_id: 'a'), CloudUser.new{ |u| u._id = 'a' }
    assert CloudUser.new{ |u| u._id = 'a' } != Member.new(_id: 'a')

    assert_equal :control, CloudUser.new{ |u| u._id = 'a' }.as_member(:control).role
  end

  def test_membership_changes
    u = CloudUser.new{ |u| u._id = 'test' }
    d = Domain.new
    assert d.members.empty?

    assert_raise(Mongoid::Errors::DocumentNotFound){ d.remove_members('test') }
    assert d.atomic_updates.empty?
    assert !d.has_member_changes?

    assert_same d, d.add_members
    assert_same d, d.remove_members

    assert_same d, d.add_members('test')
    assert_equal 1, d.members.length
    assert_equal 'test', d.members.first._id
    assert !d.members.last.explicit_grant?
    assert_equal Domain.default_role, d.members.last.role
    assert d.members.last.valid?

    d.add_members('other', :owner)
    assert_equal 2, d.members.length
    assert_equal 'other', d.members.last._id
    assert_equal ['owner'], d.members.last.from
    assert !d.members.last.explicit_grant?

    d.add_members('other')
    assert_equal 2, d.members.length
    assert_equal 'other', d.members.last._id
    assert_equal ['owner'], d.members.last.from
    assert d.members.last.explicit_grant?

    d.remove_members('other')
    assert_equal 2, d.members.length
    assert_equal 'other', d.members.last._id
    assert_equal ['owner'], d.members.last.from
    assert !d.members.last.explicit_grant?

    d.remove_members('other', :domain)
    assert_equal 2, d.members.length

    d.remove_members('other', :owner)
    assert_equal 1, d.members.length
    assert_equal 'test', d.members.first._id

    d.remove_members('test')
    assert d.members.empty?
    assert d.atomic_updates.empty?
    assert !d.has_member_changes?
  end

  def test_user_access_controllable
    CloudUser.where(:login => 'propagate_test').delete
    u = CloudUser.create(:login => 'propagate_test')

    assert_equal nil, CloudUser.member_type
    assert_equal [u], CloudUser.members_of(u._id)
    assert_equal [u], CloudUser.members_of([u._id])
    assert_equal [u], CloudUser.members_of([u])

    d = Domain.new
    assert CloudUser.members_of(d).empty?
    d.members << u.as_member
    assert_equal [u], CloudUser.members_of(d).to_a
  end

  def test_scopes_restricts_access
    u = CloudUser.find_or_create_by(:login => 'scope_test')
    t = Authorization.create(:expires_in => 100){ |token| token.user = u }

    #u2 = CloudUser.find_or_create_by(:login => 'scope_test_other')
    Domain.where(:namespace => 'test').delete
    d = Domain.find_or_create_by(:namespace => 'test', :owner => u)
    Domain.where(:namespace => 'test2').delete
    d2 = Domain.find_or_create_by(:namespace => 'test2', :owner => u)

    Application.where(:name => 'scopetest').delete
    assert a = Application.create(:name => 'scopetest', :domain => d)
    Application.where(:name => 'scopetest2').delete
    assert a2 = Application.create(:name => 'scopetest2', :domain => d2)

    assert Application.accessible(u).count > 0
    assert Domain.accessible(u).count > 0
    assert CloudUser.accessible(u).count > 0
    assert Authorization.accessible(u).count > 0

    u.scopes = Scope.list!("application/#{a._id}/read")
    assert_equal [a._id], Application.accessible(u).map(&:_id)
    assert_equal [d._id], Domain.accessible(u).map(&:_id)
    assert CloudUser.accessible(u).empty?
    assert Authorization.accessible(u).empty?

    u.scopes = Scope.list!("application/#{a2._id}/read")
    assert_equal [d2._id], Domain.accessible(u).map(&:_id)

    u.scopes = Scope.list!("application/#{Moped::BSON::ObjectId.new}/read")
    assert Application.accessible(u).empty?
    assert_raises(Mongoid::Errors::DocumentNotFound){ Domain.accessible(u).empty? }
    assert CloudUser.accessible(u).empty?
    assert Authorization.accessible(u).empty?

    u.scopes = Scope.list!("domain/#{d._id}/read")
    assert_equal [a._id], Application.accessible(u).map(&:_id)
    assert_equal [d._id], Domain.accessible(u).map(&:_id)
    assert CloudUser.accessible(u).empty?
    assert Authorization.accessible(u).empty?

    u.scopes = Scope.list!("domain/#{d2._id}/read")
    assert_equal [a2._id], Application.accessible(u).map(&:_id)
    assert_equal [d2._id], Domain.accessible(u).map(&:_id)
    assert CloudUser.accessible(u).empty?
    assert Authorization.accessible(u).empty?
  end

  def test_domain_model_consistent
    CloudUser.where(:login => 'propagate_test').delete
    Domain.where(:namespace => 'test').delete

    assert d = Domain.create(:namespace => 'test')
    u = CloudUser.create(:login => 'propagate_test')
    assert_equal Member.new(_id: u._id), u.as_member

    d.changing_members{ self.members << u.as_member }
    assert d.atomic_updates['$pushAll'].has_key?('members')
    assert d.atomic_updates['$pushAll']['members'].present?

    assert d.has_member_changes?
    assert_nil d.members.last.role

    assert !d.save

    d.members.last.role = Domain.default_role

    assert d.save
    assert d.atomic_updates.empty?
    assert_equal 1, d.pending_ops.length

    assert d.has_member?(u)
    assert u.member_of?(d)
    assert !d.has_member_changes?

    assert d2 = Domain.find_by(:namespace => 'test')
    assert_equal 1, d2.pending_ops.length
    assert op = d2.pending_ops.last
    assert_equal :change_members, op.op_type
    assert_equal [u._id], op.args['added']
    assert_nil op.args['removed']

    d.run_jobs
    assert d.pending_ops.empty?
    assert Domain.find_by(:namespace => 'test').pending_ops.empty?

    d.changing_members{ self.members.pop }
    assert d.save
    assert d.atomic_updates.empty?
    assert_equal 1, d.pending_ops.length

    assert d2 = Domain.find_by(:namespace => 'test')
    assert_equal 1, d2.pending_ops.length
    assert op = d2.pending_ops.last
    assert_equal :change_members, op.op_type
    assert_equal [u._id], op.args['removed']
    assert_nil op.args['added']

    d.run_jobs
    assert d.pending_ops.empty?
    assert Domain.find_by(:namespace => 'test').pending_ops.empty?
  end

  def test_domain_propagates_changes_to_application
    CloudUser.in(:login => ['propagate_test', 'propagate_test_2', 'propagate_test_3']).delete
    Domain.where(:namespace => 'test').delete
    Application.where(:name => 'propagatetest').delete
    Application.any_instance.expects(:run_jobs).twice

    assert u = CloudUser.create(:login => 'propagate_test')
    assert_equal Member.new(_id: u._id), u.as_member
    assert u2 = CloudUser.create(:login => 'propagate_test_2')
    assert u3 = CloudUser.create(:login => 'propagate_test_3')

    assert d = Domain.create(:namespace => 'test', :owner => u)
    assert_equal [Member.new(_id: u._id)], d.members
    assert_equal ['owner'], d.members.first.from
    assert d.members.first.valid?
    assert_equal Domain.default_role, d.members.first.role

    assert a = Application.create(:name => 'propagatetest', :domain => d)
    assert_equal [Member.new(_id: u._id)], d.members
    assert_equal ['domain'], d.members.first.from
    assert_equal Application.default_role, a.members.first.role

    assert     Application.accessible(u).first
    assert_nil Application.accessible(u2).first
    assert_nil Application.accessible(u3).first

    a.add_members(u2)

    d.add_members(u2)
    d.add_members(u3)
    assert !d.atomic_updates.empty?

    assert d.save
    assert_equal 3, d.members.length

    assert Domain.accessible(u).first
    assert Domain.accessible(u2).first
    assert Domain.accessible(u3).first
    
    d.run_jobs

    assert Application.accessible(u).first
    assert Application.accessible(u2).first
    assert Application.accessible(u3).first

    assert jobs = d.applications.first.pending_op_groups
    assert jobs.length == 1
    assert_equal :change_members, jobs.first.op_type
    assert_equal [u2._id, u3._id], jobs.last.args['added']

    a = d.applications.first
    assert_equal 3, (a.members & d.members).length
    a.members.each{ |m| assert_equal ['domain'], m.from }
    assert a.members[1].explicit_grant?

    assert d.pending_ops.empty?
    assert Domain.find_by(:namespace => 'test').pending_ops.empty?

    d.remove_members(u2)
    d.remove_members(u3)
    assert d.save
    assert d.atomic_updates.empty?
    assert_equal 1, d.pending_ops.length
    assert_equal 1, d.members.length

    assert Application.accessible(u).first
    assert Application.accessible(u2).first
    assert Application.accessible(u3).first

    d.run_jobs

    assert_nil Application.accessible(u3).first

    a = Domain.find_by(:namespace => 'test').applications.first
    assert jobs = a.pending_op_groups

    assert jobs.length == 2
    assert_equal :change_members, jobs.last.op_type
    assert_equal [u3._id], jobs.last.args['removed']

    assert_equal 1, (a.members & d.members).length
    assert_equal 2, a.members.length
    assert_equal [], a.members.last.from
    assert !a.members.last.explicit_grant?
    assert  a.members.include?(u2.as_member)
    assert !a.members.include?(u3.as_member)

    assert d.pending_ops.empty?
    assert Domain.find_by(:namespace => 'test').pending_ops.empty?
  end
end