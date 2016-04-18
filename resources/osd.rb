#
# Cookbook Name:: cephr
# Resource:: osd
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

resource_name 'ceph_osd'

property :name, String, name_property: true
property :host, String, required: true
property :dev, String
property :journal, String
property :fs_type, String, default: 'xfs'
property :uuid, String
property :id, Integer
property :bootstrap_client, String, default: 'client.bootstrap-osd'
property :bootstrap_keyring, String
property :bootstrap_secret, String

load_current_value do
  current_value_does_not_exist! unless exists?(name.split('.')[1])
end

action :create do
  return unless new_resource.host == node['fqdn'] || new_resource.host == node['hostname']
  raise'Ceph Cluster is not available!' unless ceph_available?

  new_resource.uuid ||= SecureRandom.uuid
  new_resource.id ||= new_resource.name.split('.')[1].to_i
  new_resource.bootstrap_keyring ||= "/var/lib/ceph/bootstrap-osd/#{node.run_state['cephr']['cluster']}.keyring"
  raise 'Secret or Keyfile must be given!' unless ::File.exist?(new_resource.bootstrap_keyring) || new_resource.bootstrap_secret

  directory "/var/lib/ceph/osd/#{node.run_state['cephr']['cluster']}-#{new_resource.id}" do
    owner 'ceph'
    group 'ceph'
    mode '0750'
    recursive true
  end

  execute "ceph osd create #{new_resource.uuid} #{new_resource.id}" do
    not_if { current_resource }
  end

  if new_resource.dev
    new_resource.dev = '/dev/' + new_resource.dev unless new_resource.dev.start_with?('/')
    execute "mkfs -t #{new_resource.fs_type} #{new_resource.dev}" do
      not_if { current_resource }
    end

    execute "mount -o noatime #{dev} /var/lib/ceph/osd/#{node.run_state['cephr']['cluster']}-#{new_resource.id}" do
      not_if { current_resource }
      notifies :create, "directory[/var/lib/ceph/osd/#{node.run_state['cephr']['cluster']}-#{new_resource.id}]", :immediately
    end
  end

  ceph_keyring new_resource.bootstrap_client do
    keyring new_resource.bootstrap_keyring
    secret new_resource.bootstrap_secret
    not_if { ::File.exist?(new_resource.bootstrap_keyring) }
    only_if { new_resource.bootstrap_secret }
  end

  execute "ceph-osd -i #{new_resource.id} --mkfs --mkkey --osd-uuid #{new_resource.uuid}" do
    user 'ceph'
    not_if { current_resource }
  end

  file "/var/lib/ceph/osd/#{node.run_state['cephr']['cluster']}-#{new_resource.id}/done" do
    user 'ceph'
    action :touch
  end

  service 'ceph.target' do
    supports restart: true, status: true
    action [:enable, :start]
  end if Chef::Platform::ServiceHelpers.service_resource_providers.include?(:systemd)

  service "ceph-osd-#{new_resource.id}" do
    if Chef::Platform::ServiceHelpers.service_resource_providers.include?(:systemd)
      service_name "ceph-osd@#{new_resource.id}.service"
    elsif Chef::Platform::ServiceHelpers.service_resource_providers.include?(:upstart)
      service_name 'ceph-osd'
      parameters id: new_resource.id
    end
    supports restart: true, status: true
    action [:enable, :start]
  end
end

def exists?(osd)
  require 'timeout'
  begin
    Timeout.timeout(5) do
      Mixlib::ShellOut.new("ceph osd find #{osd}").run_command.error!
      true
    end
  rescue
    false
  end
end
