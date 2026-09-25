class DigitalJobCardPolicy < ApplicationPolicy
  def destroy?
    admin_or_super_admin? || scheduler? || record_owner_or_admin?
  end

  def show?
    admin_or_super_admin? || scheduler? || record_owner_or_admin?
  end

  def update?
    admin_or_super_admin? || record_owner_or_admin?
  end

  def edit?
    update?
  end

  def print?
    show?
  end
end