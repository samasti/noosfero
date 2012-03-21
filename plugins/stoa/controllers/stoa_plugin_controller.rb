class StoaPluginController < PublicController
  append_view_path File.join(File.dirname(__FILE__) + '/../views')

  def authenticate
    if request.ssl? && request.post?
      user = User.authenticate(params[:login], params[:password], environment)
      if user
        result = {
          :username => user.login,
          :email => user.email,
          :name => user.name,
          :nusp => user.person.usp_id,
          :first_name => user.name.split(' ').first,
          :surname => user.name.split(' ',2).last,
          :address => user.person.address,
          :homepage => user.person.url,
        }
      else
        result = { :error => _('Incorrect user/password pair.') }
      end
      render :text => result.to_json
    else
      render :text => { :error => _('Conection requires SSL certificate and post method.') }.to_json
    end
  end

  def check_usp_id
    begin
      render :text => { :exists => StoaPlugin::UspUser.exists?(params[:usp_id]) }.to_json
    rescue Exception => exception
      render :text => { :exists => false, :error => {:message => exception.to_s, :backtrace => exception.backtrace} }.to_json
    end
  end

end
