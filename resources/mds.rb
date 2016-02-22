#
# Cookbook Name:: cerny_ceph
# Resource:: mds
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
# rubocop:disable Metrics/MethodLength

require_relative '../libraries/helpers'
include CernyCeph::Helpers

resource_name 'ceph_mds'

property :name, String, name_property: true
property :bootstrap_client, String, default: 'client.bootstrap-mds'
property :bootstrap_keyring, String
property :bootstrap_secret, String

load_current_value do
  current_value_does_not_exist! unless exists?(name)
end

action :create do
  new_resource.bootstrap_keyring ||= "/var/lib/ceph/bootstrap-mds/#{node.run_state['ceph']['cluster']}.keyring"
  raise 'Secret or Keyfile must be given!' unless ::File.exist?(new_resource.bootstrap_keyring) || new_resource.bootstrap_secret

  directory "/var/lib/ceph/mds/#{node.run_state['ceph']['cluster']}-#{new_resource.name}" do
    owner 'ceph'
    group 'ceph'
    mode '0750'
    recursive true
  end

  ceph_keyring new_resource.bootstrap_client do
    keyring new_resource.bootstrap_keyring
    secret new_resource.bootstrap_secret
    not_if { ::File.exist?(new_resource.bootstrap_keyring) }
    only_if { new_resource.bootstrap_secret }
  end

  ceph_auth "mds.#{new_resource.name}" do
    caps mon: 'allow profile mds',
         osd: 'allow rwx',
         mds: 'allow'
    client new_resource.bootstrap_client
    keyring new_resource.bootstrap_keyring
    output "/var/lib/ceph/mds/#{node.run_state['ceph']['cluster']}-#{new_resource.name}/keyring"
    not_if { ::File.exist?("/var/lib/ceph/mds/#{node.run_state['ceph']['cluster']}-#{new_resource.name}/keyring") }
  end

  file "/var/lib/ceph/mds/#{node.run_state['ceph']['cluster']}-#{new_resource.name}/done" do
    action :touch
    owner 'ceph'
    group 'ceph'
    mode '0640'
  end

  service 'ceph.target' do
    supports restart: true, status: true
    action [:enable, :start]
  end if Chef::Platform::ServiceHelpers.service_resource_providers.include?(:systemd)

  service 'ceph-mds' do
    if Chef::Platform::ServiceHelpers.service_resource_providers.include?(:systemd)
      service_name "ceph-mds@#{new_resource.name}.service"
    elsif Chef::Platform::ServiceHelpers.service_resource_providers.include?(:upstart)
      service_name 'ceph-mds'
      parameters id: new_resource.name
    end
    supports restart: true, status: true
    action [:enable, :start]
  end
end

def exists?(mds)
  require 'timeout'
  begin
    Timeout.timeout(5) do
      cmd = Mixlib::ShellOut.new("ceph mds stat #{mds}").run_command
      cmd.error!

      # For some reason MDS thinks it's healthy if there is no MDS cluster.
      if cmd.stdout.eql?('e1: 0/0/0 up')
        false
      else
        true
      end
    end
  rescue
    false
  end
end
