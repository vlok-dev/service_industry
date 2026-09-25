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

  class Scope < ApplicationPolicy::Scope
    def resolve
      case user&.role
      when "super_admin", "admin", "accountant", "scheduler"
        scope.all
      when "reporter"
        scope.where(user_id: user.id)
      else
        scope.none
      end
    end
  end
end