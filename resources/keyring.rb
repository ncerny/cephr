#
# Cookbook Name:: cephr
# Resource:: keyring
#
# Copyright 2016 Nathan Cerny
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# rubocop:disable LineLength

require_relative '../libraries/helpers'
include CephR::Helpers

resource_name 'ceph_keyring'

property :entity, String, name_property: true
property :keyring, String, required: true
property :caps, [String, Hash]
property :secret, String
property :import, [String, Array]
property :uid, Integer

load_current_value do
  current_value_does_not_exist! unless exists?(entity)
end

action :write do
  raise 'Must define secret!' unless new_resource.secret

  directory ::File.dirname(new_resource.keyring) do
    owner 'ceph'
    group 'ceph'
    mode '0750'
    recursive true
  end

  execute "Create #{entity} Keyring" do
    command "ceph-authtool --create-keyring #{new_resource.keyring} --add-key=#{new_resource.secret} --name #{new_resource.entity} #{(new_resource.uid ? "--set-uid=#{new_resource.uid}" : '')} #{strcaps}"
    user 'ceph'
    creates new_resource.keyring
  end
end

action :add do
  raise 'Must define secret!' unless new_resource.secret

  execute "Create #{entity} Keyring" do
    command "ceph-authtool #{new_resource.keyring} --add-key=#{new_resource.secret} --name #{new_resource.entity} #{(new_resource.uid ? "--set-uid=#{new_resource.uid}" : '')} #{strcaps}"
    user 'ceph'
    not_if "ceph-authtool --list #{new_resource.keyring} | grep #{new_resource.entity}"
  end
end

action :import do
  raise 'Must define import keyring!' unless new_resource.import
  new_resource.import = [new_resource.import] if new_resource.import.is_a?(String)
  new_resource.import.each do |val|
    execute "Import #{val} Keyring into #{entity}" do
      command "ceph-authtool #{new_resource.keyring} --import-keyring #{val}"
      user 'ceph'
    end
  end
end

def strcaps
  str = ''
  if caps.is_a?(Hash)
    caps.each { |k, v| str += "--cap #{k} '#{v}' " }
    str.strip
  elsif caps.nil?
    ''
  else
    caps
  end
end

def exists?(entity)
  require 'timeout'
  begin
    Timeout.timeout(5) do
      Mixlib::ShellOut.new("ceph auth get #{entity}").run_command.error!
      true
    end
  rescue
    false
  end
end
