class QuotePolicy < ApplicationPolicy
  def index?
    user.scheduler? || user.super_admin? || user.reporter?
  end

  def show?
    index?
  end

  def create?
    user.super_admin? || user.reporter?
  end

  def new?
    create?
  end

  def update?
    user.super_admin? || user.reporter?
  end

  def edit?
    update?
  end

  def destroy?
    user.super_admin? || user.reporter?
  end

  def print?
    index?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      case user&.role
      when "super_admin", "scheduler", "reporter", "admin"
        scope.all
      else
        scope.none
      end
    end
  end
end
