class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    admin_or_super_admin? || false
  end

  def show?
    admin_or_super_admin? || false
  end

  def create?
    admin_or_super_admin?
  end

  def new?
    create?
  end

  def update?
    admin_or_super_admin?
  end

  def edit?
    update?
  end

  def destroy?
    admin_or_super_admin?
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      if user&.admin_or_super_admin?
        scope.all
      else
        raise NotImplementedError, "You must implement #resolve in #{self.class}"
      end
    end

    private

    attr_reader :user, :scope
  end

  private

  def admin_or_super_admin?
    user&.admin? || user&.super_admin?
  end

  def accountant?
    user&.accountant?
  end
end