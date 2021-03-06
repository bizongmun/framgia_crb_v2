class User < ActiveRecord::Base
  devise :database_authenticatable, :rememberable, :trackable, :validatable,
    :registerable, :omniauthable

  has_many :user_calendars, dependent: :destroy
  has_many :calendars, dependent: :destroy
  has_many :user_organizations, dependent: :destroy
  has_many :organizations, through: :user_organizations
  has_many :shared_calendars, through: :user_calendars, source: :calendar
  has_many :attendees, dependent: :destroy
  has_many :events
  has_many :invited_events, through: :attendees, source: :event
  has_many :places
  has_one :setting

  delegate :timezone, to: :setting, prefix: true, allow_nil: true
  delegate :timezone_name, to: :setting, prefix: true, allow_nil: true

  validates :name, presence: true, length: {maximum: 50}
  validates :email, length: {maximum: 255}

  after_create :create_calendar
  before_create :generate_authentication_token!

  scope :search, ->q{where "email LIKE '%#{q}%'"}
  scope :order_by_email, ->{order email: :asc}

  accepts_nested_attributes_for :setting

  def my_calendars
    Calendar.of_user self
  end

  def other_calendars
    Calendar.shared_with_user self
  end

  def manage_calendars
    Calendar.managed_by_user self
  end

  Settings.permissions.each_with_index do |action, permission|
    define_method("permission_#{action}?") do |calendar|
      user_calendars.find_by calendar: calendar, permission_id: permission + 1
    end
  end

  def has_permission? calendar
    user_calendars.find_by calendar: calendar
  end

  def default_calendar
    calendars.find_by is_default: true
  end

  def is_user? user
    self ==  user
  end

  class << self
    def existed_email? email
      User.pluck(:email).include? email
    end

    def from_omniauth auth
      wher(provider: auth.provider, uid: auth.uid).first_or_create do |user|
        user.provider = auth.provider
        user.uid = auth.uid
        user.email = auth.info.email
        user.password = Devise.friendly_token[0,20]
      end
    end

    def find_for_google_oauth2 access_token, user
      user.provider = access_token.provider
      user.uid = access_token.uid
      user.token = access_token.credentials.token
      user.expires_at = access_token.credentials.expires_at
      user.refresh_token = access_token.credentials.refresh_token
      user.save
      user
    end

  end

  def generate_authentication_token!
    self.auth_token = Devise.friendly_token while
      self.class.exists? auth_token: auth_token
  end

  private
  def create_calendar
    self.calendars.create({name: self.name, is_default: true})
  end
end
