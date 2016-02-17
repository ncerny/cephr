#
# Cookbook Name:: cerny_ceph
# Resource:: mon
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
include CernyCeph::Helpers

resource_name 'ceph_mon'

property :name, String, name_property: true
property :monitor_secret, String, required: true
property :admin_secret, String, required: true
property :osd_bootstrap_secret, String, required: true

load_current_value do

end

action :create do
  directory "/var/lib/ceph/mon/ceph-#{new_resource.name}" do
    owner 'ceph'
    group 'ceph'
    mode '0750'
    recursive true
    action :create
  end

  directory '/var/lib/ceph/tmp/' do
    owner 'ceph'
    group 'ceph'
    mode '0750'
    recursive true
    action :create
  end

  execute 'Create Monitor Keyring' do
    command "ceph-authtool --create-keyring /var/lib/ceph/tmp/#{node.run_state['ceph']['cluster']}.mon.keyring --add-key=#{new_resource.monitor_secret} --name=mon. --cap mon 'allow *'"
    user 'ceph'
    not_if { ::File.exist?("/var/lib/ceph/mon/ceph-#{new_resource.name}/done") }
  end

  execute 'Create Admin Keyring' do
    command "ceph-authtool --create-keyring /etc/ceph/#{node.run_state['ceph']['cluster']}.client.admin.keyring --add-key=#{new_resource.admin_secret} -n client.admin --set-uid=0 --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow'"
    user 'ceph'
    creates '/etc/ceph/ceph.client.admin.keyring'
  end

  execute 'Import Admin Keyring into Monitor Keyring' do
    command "ceph-authtool /var/lib/ceph/tmp/#{node.run_state['ceph']['cluster']}.mon.keyring --import-keyring /etc/ceph/#{node.run_state['ceph']['cluster']}.client.admin.keyring"
    user 'ceph'
    not_if { ::File.exist?("/var/lib/ceph/mon/ceph-#{new_resource.name}/done") }
  end

  execute 'add bootstrap-osd key to keyring' do
    command "ceph-authtool /var/lib/ceph/tmp/#{node.run_state['ceph']['cluster']}.mon.keyring --name=client.bootstrap-osd --add-key='#{new_resource.osd_bootstrap_secret}' --cap mon 'allow profile bootstrap-osd'  --cap osd 'allow profile bootstrap-osd'"
    user 'ceph'
    not_if { ::File.exist?("/var/lib/ceph/mon/ceph-#{new_resource.name}/done") }
  end

  execute 'Add this monitor to monmap' do
    command "monmaptool --create --add #{new_resource.name} #{node.run_state['ceph']['monitors'][new_resource.name]} --fsid #{node.run_state['ceph']['config']['global']['fsid']} /var/lib/ceph/tmp/monmap"
    not_if { ::File.exist?("/var/lib/ceph/mon/ceph-#{new_resource.name}/done") }
  end

  # This is ugly.  State management is hard...this hack should work though.
  node.run_state['ceph']['monitors'].each do |host, ip|
    execute "Add monitor #{host} to monmap" do
      command "monmaptool --add #{host} #{ip} --fsid #{node.run_state['ceph']['config']['global']['fsid']} /var/lib/ceph/tmp/monmap"
      returns [0, 1]
      not_if { ::File.exist?("/var/lib/ceph/mon/ceph-#{new_resource.name}/done") }
    end
  end

  execute 'Populate Monitor Daemon' do
    command "ceph-mon --mkfs -i #{node['fqdn']} --monmap /var/lib/ceph/tmp/monmap --keyring /var/lib/ceph/tmp/#{node.run_state['ceph']['cluster']}.mon.keyring"
    user 'ceph'
    not_if { ::File.exist?("/var/lib/ceph/mon/ceph-#{new_resource.name}/done") }
  end

  file "/var/lib/ceph/mon/ceph-#{new_resource.name}/done" do
    user 'ceph'
    action :touch
  end

  service 'ceph.target' do
    supports restart: true, status: true
    action [:enable, :start]
  end if Chef::Platform::ServiceHelpers.service_resource_providers.include?(:systemd)

  service 'ceph-mon' do
    if Chef::Platform::ServiceHelpers.service_resource_providers.include?(:systemd)
      service_name "ceph-mon@#{node['fqdn']}.service"
    elsif Chef::Platform::ServiceHelpers.service_resource_providers.include?(:upstart)
      service_name 'ceph-mon'
      parameters id: node['fqdn']
    end
    supports restart: true, status: true
    action [:enable, :start]
  end
end
