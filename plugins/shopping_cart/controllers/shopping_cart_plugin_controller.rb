require 'base64'

class ShoppingCartPluginController < PublicController

  include ShoppingCartPlugin::CartHelper
  helper ShoppingCartPlugin::CartHelper

  append_view_path File.join(File.dirname(__FILE__) + '/../views')
  before_filter :login_required, :only => []

  before_filter :login_required, :only => []

  def get
    config =
      if cart.nil?
        { 'enterprise_id' => nil, 'hasProducts' => false }
      else
        { 'enterprise_id' => cart[:enterprise_id], 'hasProducts' => (cart[:items].keys.size > 0) }
      end
    render :text => config.to_json
  end

  def add
    product = find_product(params[:id])
    if product && enterprise = validate_same_enterprise(product)
      self.cart = { :enterprise_id => enterprise.id, :items => {} } if self.cart.nil?
      self.cart[:items][product.id] = 0 if self.cart[:items][product.id].nil?
      self.cart[:items][product.id] += 1
      render :text => {
        :ok => true,
        :error => {:code => 0},
        :products => [{
          :id => product.id,
          :name => product.name,
          :price => get_price(product, enterprise.environment),
          :description => product.description,
          :picture => product.default_image(:minor),
          :quantity => self.cart[:items][product.id]
        }]
      }.to_json
    end
  end

  def remove
    id = params[:id].to_i
    if validate_cart_presence && validate_cart_has_product(id)
      self.cart[:items].delete(id)
      self.cart = nil if self.cart[:items].empty?
      render :text => {
        :ok => true,
        :error => {:code => 0},
        :product_id => id
      }.to_json
    end
  end

  def list
    if validate_cart_presence
      products = self.cart[:items].collect do |id, quantity|
        product = Product.find(id)
        { :id => product.id,
          :name => product.name,
          :price => get_price(product, product.enterprise.environment),
          :description => product.description,
          :picture => product.default_image(:minor),
          :quantity => quantity
        }
      end
      render :text => {
        :ok => true,
        :error => {:code => 0},
        :products => products
      }.to_json
    end
  end

  def update_quantity
    quantity = params[:quantity].to_i
    id = params[:id].to_i
    if validate_cart_presence && validate_cart_has_product(id) && validate_item_quantity(quantity)
      product = Product.find(id)
      self.cart[:items][product.id] = quantity
      render :text => {
        :ok => true,
        :error => {:code => 0},
        :product_id => id,
        :quantity => quantity
      }.to_json
    end
  end

  def clean
    self.cart = nil
    render :text => {
      :ok => true,
      :error => {:code => 0}
    }.to_json
  end

  def buy
    @cart = cart
    @enterprise = environment.enterprises.find(cart[:enterprise_id])
    render :layout => false
  end

  def send_request
    register_order(params[:customer], self.cart[:items])
    begin
      enterprise = Enterprise.find(cart[:enterprise_id])
      ShoppingCartPlugin::Mailer.deliver_customer_notification(params[:customer], enterprise, self.cart[:items])
      ShoppingCartPlugin::Mailer.deliver_supplier_notification(params[:customer], enterprise, self.cart[:items])
      render :text => {
        :ok => true,
        :message => _('Request sent successfully. Check your email.'),
        :error => {:code => 0}
      }.to_json
    rescue Exception => exception
      render :text => {
        :ok => false,
        :error => {
          :code => 6,
          :message => exception.message
        }
      }.to_json
    end
  end

  def visibility
    render :text => self.cart.has_key?(:visibility) ? self.cart[:visibility].to_json : true.to_json
  end

  def show
    begin
      self.cart[:visibility] = true
      render :text => {
        :ok => true,
        :message => _('Basket displayed.'),
        :error => {:code => 0}
      }.to_json
    rescue Exception => exception
      render :text => {
        :ok => false,
        :error => {
          :code => 7,
          :message => exception.message
        }
      }.to_json
    end
  end

  def hide
    begin
      self.cart[:visibility] = false
      render :text => {
        :ok => true,
        :message => _('Basket hidden.'),
        :error => {:code => 0}
      }.to_json
    rescue Exception => exception
      render :text => {
        :ok => false,
        :error => {
          :code => 8,
          :message => exception.message
        }
      }.to_json
    end
  end

  private

  def validate_same_enterprise(product)
    if self.cart && self.cart[:enterprise_id] && product.enterprise_id != self.cart[:enterprise_id]
      render :text => {
        :ok => false,
        :error => {
        :code => 1,
        :message => _("Can't join items from different enterprises.")
      }
      }.to_json
      return nil
    end
    product.enterprise
  end

  def validate_cart_presence
    if self.cart.nil?
      render :text => {
        :ok => false,
        :error => {
        :code => 2,
        :message => _("There is no basket.")
      }
      }.to_json
      return false
    end
    true
  end

  def find_product(id)
    begin
      $stderr.puts '*********** ' + id.inspect
      product = Product.find(id)
    rescue ActiveRecord::RecordNotFound
      render :text => {
        :ok => false,
        :error => {
        :code => 3,
        :message => _("This enterprise doesn't have this product.")
      }
      }.to_json
      return nil
    end
    product
  end

  def validate_cart_has_product(id)
    if !self.cart[:items].has_key?(id)
      render :text => {
        :ok => false,
        :error => {
        :code => 4,
        :message => _("The basket doesn't have this product.")
      }
      }.to_json
      return false
    end
    true
  end

  def validate_item_quantity(quantity)
    if quantity.to_i < 1
      render :text => {
        :ok => false,
        :error => {
        :code => 5,
        :message => _("Invalid quantity.")
      }
      }.to_json
      return false
    end
    true
  end

  def register_order(custumer, items)
    new_items = {}
    items.each do |id, quantity|
      product = Product.find(id)
      price = product.price || 0
      new_items[id] = {:quantity => quantity, :price => price, :name => product.name}
    end
    ShoppingCartPlugin::PurchaseOrder.create!(
      :seller => Enterprise.find(cart[:enterprise_id]),
      :customer => user,
      :status => ShoppingCartPlugin::PurchaseOrder::Status::OPENED,
      :products_list => new_items,
      :customer_name => params[:customer][:name],
      :customer_email => params[:customer][:email],
      :customer_contact_phone => params[:customer][:contact_phone],
      :customer_address => params[:customer][:address],
      :customer_city => params[:customer][:city],
      :customer_zip_code => params[:customer][:zip_code]
    )
  end

  protected

  def cart
    @cart ||=
      begin
        cookies[cookie_key] && YAML.load(Base64.decode64(cookies[cookie_key])) || nil
      end
    @cart
  end

  def cart=(data)
    @cart = data
  end

  after_filter :save_cookie
  def save_cookie
    if @cart.nil? && cookies[cookie_key]
      cookies.delete(cookie_key)
    else
      cookies[cookie_key] = {
        :value => Base64.encode64(@cart.to_yaml),
        :path => "/plugin/shopping_cart"
      }
    end
  end

  def cookie_key
    :_noosfero_session_shopping_cart
  end

end
