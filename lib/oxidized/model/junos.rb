class JunOS < Oxidized::Model
  using Refinements
  comment '# '

  def telnet
    @input.class.to_s.match(/Telnet/)
  end

  def sanitize_json(json_obj)
    case json_obj
    when Hash
      json_obj.each do |key, value|
        if key == 'name' && json_obj.key?('community')
          json_obj[key] = '<secret removed>'
        elsif key == 'secret'
          json_obj[key] = '<secret removed>'
        else
          sanitize_json(value)
        end
      end
    when Array
      json_obj.each { |item| sanitize_json(item) }
    end
  end

  def safe_parse_json(json_str)
    JSON.parse(json_str.encode('UTF-8', 'binary', invalid: :replace, undef: :replace, replace: ''))
  end

  cmd 'show version | display json' do |cfg|
    @model = Regexp.last_match(1) if cfg =~ /^Model: (\S+)/
    version_info = safe_parse_json(cfg)
    sanitize_json(version_info)
    @outputs ||= {}
    @outputs['version'] = version_info
    ''
  end

  post do
    @outputs ||= {}

    case @model
    when 'mx960'
      out = cmd('show chassis fabric reachability | display json')
      chassis_fabric_reachability = safe_parse_json(out)
      sanitize_json(chassis_fabric_reachability)
      @outputs['chassis-fabric-reachability'] = chassis_fabric_reachability
    when /^(ex22|ex3[34]|ex4|ex8|qfx)/
      out = cmd('show virtual-chassis | display json')
      virtual_chassis = safe_parse_json(out)
      sanitize_json(virtual_chassis)
      @outputs['virtual-chassis'] = virtual_chassis
    end

    out = cmd('show chassis hardware | display json')
    chassis_hardware = safe_parse_json(out)
    sanitize_json(chassis_hardware)
    @outputs['chassis-hardware'] = chassis_hardware

    out = cmd('show system license | display json')
    system_license = safe_parse_json(out)
    sanitize_json(system_license)
    @outputs['system-license'] = system_license

    out = cmd('show system license keys | display json')
    system_license_keys = safe_parse_json(out)
    sanitize_json(system_license_keys)
    @outputs['system-license-keys'] = system_license_keys

    out = cmd('show configuration | display json')
    configuration = safe_parse_json(out)['configuration'] # the configuration comes inside a 'configuration' object, bit dumb...
    sanitize_json(configuration)
    @outputs['configuration'] = configuration

    JSON.pretty_generate(@outputs)
  end

  cfg :telnet do
    username(/^login:/)
    password(/^Password:/)
  end

  cfg :ssh do
    exec true # don't run shell, run each command in exec channel
  end

  cfg :telnet, :ssh do
    post_login 'set cli screen-length 0'
    post_login 'set cli screen-width 0'
    pre_logout 'exit'
  end
end
