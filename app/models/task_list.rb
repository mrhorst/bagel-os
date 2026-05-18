class TaskList < ApplicationRecord
  has_many :tasks, dependent: :restrict_with_error
  has_many :task_occurrences, dependent: :restrict_with_error

  before_validation :assign_key

  validates :name, presence: true
  validates :key, presence: true, uniqueness: true
  validates :position, numericality: { only_integer: true }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  def self.key_for(value)
    value.to_s.downcase.gsub(/&/, " and ").gsub(/[^a-z0-9]+/, " ").squish.parameterize
  end

  def archive!
    transaction do
      update!(active: false)
      tasks.active.find_each(&:archive!)
    end
  end

  def reactivate!
    update!(active: true)
  end

  def archived?
    !active?
  end

  private

  def assign_key
    self.key = self.class.key_for(name) if key.blank? && name.present?
  end
end
